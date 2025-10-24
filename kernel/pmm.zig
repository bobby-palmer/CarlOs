//! Global Buddy allocator for managing phyical memory. All add ram calls
//! should be made before using the allocator functions

const std = @import("std");
const common = @import("common.zig");
const SpinLock = @import("spinlock.zig");

pub const MemBlock = struct {
    start: usize,
    end: usize,
};

/// Metadata for phyical page
pub const Page = struct {

    flags: struct {
        /// Page is managed by pmm
        free: u1,

        /// Page is reserved (openSbi and whatnot)
        reserved: u1,
    },

    payload: union(enum) {
        free: struct {
            node: std.DoublyLinkedList.Node,
            order: u8,
        }
    },
};

const Error = error {
    OutOfMemory,
    MaxOrderExceeded,
};

/// Add a new ram region to the phyical memory manager. Should not overlap with
/// any previously added regions. This is not concurrently safe
pub fn addRam(ram: MemBlock, reserved: []const MemBlock) void {

    if (next_region >= MAX_REGIONS) {
        return;
    }

    const start_ppn = common.pageUp(ram.start);
    const end_ppn = common.pageDown(ram.end);

    var first_after_reserved = start_ppn;

    for (reserved) |entry| {
        if (entry.start < ram.end and ram.start < entry.end) {
            first_after_reserved = @max(
                first_after_reserved,
                common.pageUp(entry.end)
            );
        }
    }

    const pages_needed = ( (end_ppn - start_ppn) * @sizeOf(Page) 
        + common.PAGE_SIZE - 1) / common.PAGE_SIZE;

    if (first_after_reserved + pages_needed > end_ppn) {
        return; // there isnt enough room to store page metadata
    }

    const pages_ptr: [*]Page = @ptrFromInt(common.addrOfPage(first_after_reserved));

    @memset(std.mem.sliceAsBytes(pages_ptr[0..end_ppn - start_ppn]), 0);

    regions[next_region] = MemRegion {
        .start_ppn = start_ppn,
        .end_ppn = end_ppn,
        .pages = pages_ptr,
    };

    next_region += 1;

    for (reserved) |entry| {
        for (common.pageDown(entry.start)..common.pageUp(entry.end)) |ppn| {
            if (start_ppn <= ppn and ppn < end_ppn) {
                const page = pageOfPpn(ppn) orelse unreachable;
                page.flags.reserved = 1;
                page.flags.free = 0;
            }
        }
    }

    // Reserve memory used for page metadata
    for (0..pages_needed) |offset| {
        const page = pageOfPpn(first_after_reserved + offset) orelse unreachable;
        page.flags.reserved = 1;
        page.flags.free = 0;
    }

    for (start_ppn..end_ppn) |ppn| {
        const page = pageOfPpn(ppn) orelse unreachable;
        if (page.flags.reserved == 0) {
            free(common.addrOfPage(ppn), 0);
        }
    }
}

pub fn alloc(order: u8) Error!usize {
    if (order > MAX_ORDER) {
        return Error.MaxOrderExceeded;
    }

    lock.lock();
    defer lock.unlock();

    for (order..MAX_ORDER + 1) |order_to_try| {
        if (buddy_lists[order_to_try].pop()) |node| {
            const page: *Page = @fieldParentPtr("payload.free.node", node);
            const ppn = ppnOfPage(page);

            var current_order = order_to_try;
            while (current_order > order) : (current_order -= 1) {
                const buddy_ppn = ppn + (@as(u64, 1) << @intCast(current_order - 1));
                const buddy_page = pageOfPpn(buddy_ppn) orelse unreachable;

                buddy_page.flags.free = 1;
                buddy_page.payload.free.order = current_order - 1;
                buddy_lists[current_order - 1].prepend(buddy_page.payload.free.node);
            }

            page.flags.free = 0;
            return common.addrOfPage(ppn);
        }
    }

    return Error.OutOfMemory;
}

pub fn free(base_addr: usize, order: u8) void {
    std.debug.assert(order <= MAX_ORDER);
    std.debug.assert(std.mem.isAligned(base_addr, common.PAGE_SIZE << @intCast(order)));

    lock.lock();
    defer lock.unlock();

    var current_ppn = common.pageDown(base_addr);
    var current_order = order;

    while (current_order < MAX_ORDER) {
        const buddy_ppn = current_ppn ^ (@as(u64, 1) << @intCast(current_order));
        const buddy_page = pageOfPpn(buddy_ppn) orelse break;

        if (buddy_page.flags.free == 1 and buddy_page.payload.free.order == current_order) {
            buddy_lists[current_order].remove(&buddy_page.payload.free.node);
            current_ppn = @min(current_ppn, buddy_ppn);
            current_order += 1;
        } else {
            break;
        }
    }

    const free_page = pageOfPpn(current_ppn) orelse unreachable;
    free_page.flags.free = 1;
    free_page.payload.free.order = current_order;
    buddy_lists[current_order].prepend(&free_page.payload.free.node);
}

/// Return metadata for page starting at addr
pub fn getPage(addr: usize) ?*Page {
    std.debug.assert(std.mem.isAligned(addr, common.PAGE_SIZE));
    return pageOfPpn(common.pageDown(addr));
}

/// Return phyical page number of given page struct
fn ppnOfPage(page: *Page) u64 {
    const casted: [*]Page = @ptrCast(page);

    for (0..next_region) |idx| {
        if (regions[idx].pages <= casted and casted < regions[idx].pages + regions[idx].len()) {
            return (casted - regions[idx].pages) + regions[idx].start_ppn;
        }
    }

    unreachable;
}

/// Return the page struct for given phyical page number
fn pageOfPpn(ppn: u64) ?*Page {
    for (0..next_region) |idx| {
        if (regions[idx].start_ppn <= ppn and ppn < regions[idx].end_ppn) {
            return &regions[idx].pages[ppn - regions[idx].start_ppn];
        }
    }

    return null;
}

const MAX_REGIONS: usize = 5;
var next_region: usize = 0;

const MemRegion = struct {
    start_ppn: u64,
    end_ppn: u64,
    pages: [*]Page,

    fn len(self: *const MemRegion) usize {
        return self.end_ppn - self.start_ppn;
    }
};

var regions: [MAX_REGIONS]MemRegion = undefined;

const MAX_ORDER: usize = 10;
var buddy_lists: [MAX_ORDER + 1]std.DoublyLinkedList = 
    [_]std.DoublyLinkedList{ std.DoublyLinkedList{} } ** (MAX_ORDER + 1);

var lock = SpinLock{};
