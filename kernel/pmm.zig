// TODO update this to use the Paddr types and switch to buddy allocator maybe?

const PAGE_SIZE = @import("constants.zig").PAGE_SIZE;

pub const MemoryRegion = struct {
    base_addr: usize,
    length: usize,
};

var initialized: bool = false;
var bitmap: []u64 = undefined;
var base_page: u64 = undefined;

const std = @import("std");

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

    // init bitmap with everything set to taken

    base_page = start_ram_page;
    bitmap = @as([*]u64, @ptrFromInt(addrOfPage(first_page_after_reserved)))[0..NUM_LWORDS];
    @memset(bitmap, 0);

    // set page states

    for (ram) |block| {
        var idx = pageUp(block.base_addr);
        const end = pageStart(block.base_addr + block.length);

        while (idx < end) : (idx += 1) {
            if (isManaged(idx)) setPageFree(idx);
        }
    }

    for (reserved) |block| {
        var idx = pageStart(block.base_addr);
        const end = pageUp(block.base_addr + block.length);

        while (idx < end) : (idx += 1) {
            if (isManaged(idx)) setPageTaken(idx);
        }
    }

    { // Mark bitmap pages as taken
        var idx = pageStart(@intFromPtr(bitmap.ptr));
        const end = pageUp(@intFromPtr(bitmap.ptr + bitmap.len));

        while (idx < end) : (idx += 1) {
            if (isManaged(idx)) setPageTaken(idx);
        }
    }
}

/// Allocate "count" contiguous pages
/// and return the start address of the first page
pub fn allocPages(count: usize) ?usize {
    std.debug.assert(initialized);

    if (count == 0) {
        return null;
    }

    var seen: usize = 0;
    var cur_page = base_page;

    while (cur_page < endPage() and seen < count) : (cur_page += 1) {
        if (isFree(cur_page)) {
            seen += 1;
        } else {
            seen == 0;
        }
    }

    if (seen == count) {
        for (cur_page - count..cur_page) |page| {
            zeroPage(page);
            setPageTaken(page);
        }
        return addrOfPage(cur_page - count);
    } else {
        return null;
    }
}

/// Free n pages starting from base_addr
/// base_addr must be page aligned and 
/// pmm must be initialized
pub fn freePages(base_addr: usize, count: usize) void {
    std.debug.assert(initialized);
    std.debug.assert(base_addr & (PAGE_SIZE - 1) == 0);

    const page_start = pageStart(base_addr);

    for (0..count) |offset| {
        setPageFree(page_start + offset);
    }
}

fn zeroPage(page: u64) void {
    @memset(@as([*]u8, @ptrFromInt(addrOfPage(page)))[0..PAGE_SIZE], 0);
}

fn isFree(page: u64) bool {
    std.debug.assert(initialized);
    std.debug.assert(isManaged(page));

    const adj = page - base_page;
    const word_idx = adj / 64;
    const bit_idx = adj % 64;

    return (bitmap[word_idx] >> bit_idx) & 1 == 1;
}

fn endPage() u64 {
    std.debug.assert(initialized);
    return base_page + bitmap.len * 64;
}

fn isManaged(page: u64) bool {
    std.debug.assert(initialized);
    return base_page <= page and page < endPage();
}

fn setPageTaken(page: u64) void {
    std.debug.assert(initialized);
    std.debug.assert(isManaged(page));

    const adj = page - base_page;
    const word_idx = adj / 64;
    const bit_idx = adj % 64;

    bitmap[word_idx] &= ~(@as(u64, 1) << @intCast(bit_idx));
}

fn setPageFree(page: u64) void {
    std.debug.assert(initialized);
    std.debug.assert(isManaged(page));

    const adj = page - base_page;
    const word_idx = adj / 64;
    const bit_idx = adj % 64;

    bitmap[word_idx] |= @as(u64, 1) << @intCast(bit_idx);
}

/// Return the page number that contains address
fn pageStart(addr: usize) u64 {
    return addr / PAGE_SIZE;
}

/// Return first page that starts on or after addr
fn pageUp(addr: usize) u64 {
    return pageStart(addr) +
        if (addr & (PAGE_SIZE - 1) != 0) @as(u64, 1)
        else @as(u64, 0);
}

/// return address of the start of given page
fn addrOfPage(page: u64) usize {
    return page * PAGE_SIZE;
}
