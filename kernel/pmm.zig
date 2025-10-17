var initialized: bool = false;
var bitmap: []u64 = undefined;
var base_page: u64 = undefined;

const PAGE_ORD: u64 = 12;
pub const PAGE_SIZE: usize = 1 << PAGE_ORD; // 4KB

pub const MemoryRegion = struct {
    base_addr: usize,
    length: usize,
};

/// Initialize bitmap and page state tracking, should only be called once
/// and will panic if called twice
pub fn init(ram: []const MemoryRegion, reserved: []const MemoryRegion) void {
    if (ram.len == 0) {
        @panic("No ram to initialize pmm");
    }

    if (initialized) {
        @panic("pmm double initialized");
    }

    initialized = true;

    // Extract information needed to constuct bitmap

    var start_ram_page = pageUp(ram[0].base_addr);
    var end_ram_page = pageStart(ram[0].base_addr + ram[0].length);

    for (ram) |block| {
        start_ram_page = @min(start_ram_page, pageUp(block.base_addr));
        end_ram_page = @max(end_ram_page, pageStart(block.base_addr + block.length));
    }

    var first_page_after_reserved = start_ram_page;

    for (reserved) |block| {
        first_page_after_reserved = 
            @max(
                first_page_after_reserved,
                pageUp(block.base_addr + block.length)
            );
    }

    const NUM_LWORDS = (end_ram_page - start_ram_page + 63) / 64;

    // TODO check if enough room for bitmap

    // init bitmap with everything set to taken

    base_page = start_ram_page;
    bitmap = @as([*]u64, @ptrFromInt(addrOfPage(first_page_after_reserved)))[0..NUM_LWORDS];
    @memset(bitmap, 0);

    // set page states

    for (ram) |block| {
        var idx = pageUp(block.base_addr);
        const end = pageStart(block.base_addr + block.length);

        while (idx < end) {
            setPageFree(idx);
            idx += 1;
        }
    }

    for (reserved) |block| {
        var idx = pageStart(block.base_addr);
        const end = pageUp(block.base_addr + block.length);

        while (idx < end) {
            setPageTaken(idx);
            idx += 1;
        }
    }

    { // Mark bitmap pages as taken
        var idx = pageStart(@intFromPtr(bitmap.ptr));
        const end = pageUp(@intFromPtr(bitmap.ptr + bitmap.len));

        while (idx < end) {
            setPageTaken(idx);
            idx += 1;
        }
    }
}

fn setPageTaken(page: u64) void {
    if (page < base_page) return;

    const adj = page - base_page;
    const word_idx = adj / 64;
    const bit_idx = adj % 64;

    bitmap[word_idx] &= ~(@as(u64, 1) << @intCast(bit_idx));
}

fn setPageFree(page: u64) void {
    if (page < base_page) return;

    const adj = page - base_page;
    const word_idx = adj / 64;
    const bit_idx = adj % 64;

    bitmap[word_idx] |= @as(u64, 1) << @intCast(bit_idx);
}

/// Return the page number that contains address
fn pageStart(addr: usize) u64 {
    return addr >> PAGE_ORD;
}

/// Return first page that starts on or after addr
fn pageUp(addr: usize) u64 {
    return pageStart(addr) +
        if (addr & (PAGE_SIZE - 1) != 0) @as(u64, 1)
        else @as(u64, 0);
}

/// return address of the start of given page
fn addrOfPage(page: u64) usize {
    return page << PAGE_ORD;
}
