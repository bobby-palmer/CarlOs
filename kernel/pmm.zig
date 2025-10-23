//! Buddy allocator for managing phyical memory. TODO add spinlock for multicpu

const std = @import("std");
const common = @import("common.zig");

pub const MemoryRegion = struct {
    start: usize,
    end: usize,
};

const Error = error {
    OutOfMemory,
    MaxOrderExceeded,
};

/// Adds "ram" to the managed memory, cutting out all reserved regions
pub fn addRam(ram: MemoryRegion, reserved: []const MemoryRegion) void {
    var to_be_processed = ram;

    while (to_be_processed.start < to_be_processed.end) {
        const region_to_add = getNextUsableRegion(to_be_processed, reserved);

        var current_page = common.pageUp(region_to_add.start);
        const end_page = common.pageDown(region_to_add.end);

        while (current_page < end_page) {
            const remaining_length = end_page - current_page;
            const alignment_order = @ctz(current_page);
            const max_order = @min(
                MAX_ORDER, 
                std.math.log2_int(u64, remaining_length)
            );
            const order = @min(alignment_order, max_order);

            buddy_lists[order].insert(common.addrOfPage(current_page));
            current_page += (@as(u64, 1) << order);
        }

        to_be_processed.start = region_to_add.end;
    }
}

/// Allocates 2^order pages and returns base address of the region allocated or
/// error on failure
pub fn allocFrames(requested_order: usize) Error!usize {

    if (requested_order > MAX_ORDER) return Error.MaxOrderExceeded;

    for (requested_order..MAX_ORDER + 1) |order| {
        if (buddy_lists[order].next) |node| {

            buddy_lists[order].next = node.next;
            var current_order = order;

            while (current_order > requested_order) : (current_order -= 1) {
                const half_size = common.PAGE_SIZE << (current_order - 1);
                buddy_lists[current_order - 1].insert(
                    @intFromPtr(node) + half_size
                );
            }

            return @intFromPtr(node);
        }
    }

    return Error.OutOfMemory;
}

/// frees 2^order pages starting at "base_addr"
pub fn freeFrames(base_addr: usize, order: usize) void {
    std.debug.assert(std.mem.isAligned(base_addr, common.PAGE_SIZE << order));

    var to_insert = base_addr;

    for (order..MAX_ORDER) |current_order| {
        const buddy_addr = to_insert ^ (common.PAGE_SIZE << current_order);

        if (!buddy_lists[current_order].tryRemove(buddy_addr)) {
            buddy_lists[current_order].insert(to_insert);
            return;
        }

        to_insert = @min(to_insert, buddy_addr);
    }

    buddy_lists[MAX_ORDER].insert(to_insert);
}

/// Return the first memory region in "free" that has no overlap with reserved
fn getNextUsableRegion(free: MemoryRegion, reserved: []const MemoryRegion) 
    MemoryRegion {
    var start = free.start;
    var end = free.end;
    var changed = true;

    while (changed and start < end) {
        changed = false;

        for (reserved) |unusable_region| {
            if (unusable_region.start <= start and start < unusable_region.end) {
                changed = true;
                start = unusable_region.end;
            }

            if (start < unusable_region.start and unusable_region.start < end) {
                changed = true;
                end = unusable_region.start;
            }
        }
    }

    return MemoryRegion {
        .start = start,
        .end = @max(start, end),
    };
}

const MAX_ORDER: usize = 10;

const ListNode = struct {
    next: ?*ListNode,

    fn insert(self: *ListNode, buffer: usize) void {
        var new_node: *ListNode = @ptrFromInt(buffer);
        new_node.next = self.next;
        self.next = new_node;
    }

    /// Try to remove node with "search_addr" and return true if successful
    fn tryRemove(self: *ListNode, search_addr: usize) bool {
        if (self.next) |node| {
            if (@intFromPtr(node) == search_addr) {
                self.next = node.next;
                return true;
            } else {
                return node.tryRemove(search_addr);
            }
        } else {
            return false;
        }
    }
};

var buddy_lists: [MAX_ORDER + 1]ListNode = [_]ListNode{ListNode{.next = null }} ** (MAX_ORDER + 1);
// var free_page_count: usize = 0; TODO implement this for debugging
