//! Kernel memory allocator, created on top of the pmm to allocate non page
//! sized memory. TODO add resize and remap later

const std = @import("std");
const pmm = @import("pmm.zig");
const common = @import("common.zig");

pub const allocator = std.mem.Allocator {
    .ptr = undefined,
    .vtable = std.mem.Allocator.VTable {
        .alloc = alloc,
        .free = free,
    }
};

fn alloc(_: *anyopaque, len: usize, alignment: std.mem.Alignment, ret_addr: usize) 
    ?[*]u8 {

    _ = ret_addr; // discard;

    const order = getAllocationOrder(len, alignment);

    if (order > MAX_ALLOCATION_ORDER) {
        // Reroute directly to pmm
        const page_order = getPageOrder(order);
        const page_addr = pmm.alloc(page_order) catch return null;
        return @ptrFromInt(page_addr);
    } else {
        // Use cache allocator
        unreachable;
    }
}

fn free(_: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret_addr: usize)
    void {

    _ = ret_addr; // discard;

    const order = getAllocationOrder(memory.len, alignment);

    if (order > MAX_ALLOCATION_ORDER) {
        // Reroute directly to pmm
        const page_order = getPageOrder(order);
        pmm.free(memory.ptr, page_order);
    } else {
        // Use cache allocator
        unreachable;
    }
}

/// Need at least space for the list nodes within the buffer
const MIN_ALLOCATION_ORDER: u8 = std.math.log2_int_ceil(
    usize,
    @sizeOf(std.SinglyLinkedList.Node)
);

/// Should just allocate whole page if cant fit atleast 2 per page
const MAX_ALLOCATION_ORDER: u8 = std.math.log2_int(
    u32,
    common.PAGE_SIZE / 2
);

/// Return the min byte order (1<<order bytes) needed to accomodate this
/// request.
fn getAllocationOrder(len: usize, alignment: std.mem.Alignment) u8 {
    const len_order = std.math.log2_int_ceil(usize, len);
    const align_order = std.math.log2_int_ceil(usize, alignment.toByteUnits());

    return @max(len_order, align_order, MIN_ALLOCATION_ORDER);
}

/// Number of pages needed for 2^order bytes
fn getPageOrder(byte_order: u8) u8 {
    const page_order = std.math.log2_int(u32, common.PAGE_SIZE);

    if (page_order > byte_order) {
        return 0;
    } else {
        return byte_order - page_order;
    }
}

/// List of linked Page structs in pmm.
var allocation_caches =
    [_]std.SinglyLinkedList {std.SinglyLinkedList{}} 
    ** (MAX_ALLOCATION_ORDER - MIN_ALLOCATION_ORDER + 1);
