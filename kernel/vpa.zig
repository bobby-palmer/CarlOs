//! Kernel virtual page allocator.

const std = @import("std");
const pmm = @import("pmm.zig");
const common = @import("common.zig");

pub fn init(start_addr: usize, length: usize) void {
    std.debug.assert(std.mem.isAligned(start_addr, common.constants.PAGE_SIZE));
    std.debug.assert(std.mem.isAligned(length, common.constants.PAGE_SIZE));

    const region = allocateRegion();

    region.* = VMARegion {
        .base_addr = start_addr,
        .length = length,
        .next = .{},
    };

    free_regions.next = region;
}

pub fn alloc(bytes: usize, alignment: usize) usize {
    std.debug.assert(std.mem.isAligned(bytes, common.constants.PAGE_SIZE));
    std.debug.assert(std.mem.isAligned(alignment, common.constants.PAGE_SIZE));

    var parent = &free_regions; 

    while (parent.next) |node| : (parent = node) {
        const start_useable = 
            std.mem.alignForward(
                usize, node.base_addr, alignment);

        const end_needed = start_useable + bytes;

        if (end_needed <= node.end()) {
            
            if (node.base_addr == start_useable and node.end() == end_needed) {
                parent.next = node.next; 
            } else if (node.base_addr == start_useable) {
                node.base_addr = end_needed;
                node.length -= bytes;
            } else if (node.end() == end_needed) {
                node.length -= bytes;
            } else {
                const new_node = allocateRegion();
                new_node.base_addr = end_needed;
                new_node.length = node.end() - end_needed;
                new_node.next = node.next;

                node.next = new_node;
                node.length = start_useable - node.base_addr;
            }

            return start_useable;
        }
    }

    @panic("No Virtual space left");
}

/// Free and join region to make contiguous
pub fn free(base_addr: usize, bytes: usize) void {
    var parent = &free_regions;

    while (parent.next != null and parent.next.?.base_addr < base_addr)
        : (parent = parent.next) {}

    if (parent.end() == base_addr) {
        parent.length += bytes;
    } else {

    }
}

const VMARegion = struct {
    base_addr: usize = 0,
    length: usize = 0,
    next: ?*VMARegion = null,

    fn end(self: *const VMARegion) usize {
        return self.base_addr + self.length;
    }
};

var free_regions = VMARegion{};
var unused_nodes = VMARegion{};

fn allocateRegion() *VMARegion {

    if (unused_nodes.next == null) {
        const page = pmm.allocPage() catch @panic("VMA allocation failed");
        const start = page.getVaddr();
        const end = start + common.constants.PAGE_SIZE;

        var head: [*]VMARegion = @ptrFromInt(start);

        while (head + @sizeOf(VMARegion) <= end) : (head += @sizeOf(VMARegion)) {
            head[0].next = unused_nodes.next;
            unused_nodes.next = &head[0];
        }
    }

    const node = unused_nodes.next orelse unreachable;

    unused_nodes.next = node.next;
    node.next = null;
    return node;
}
