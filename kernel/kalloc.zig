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

}

fn free(_: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret_addr: usize) 
    void {

}

/// Need at least space for the list nodes within the buffer
const MIN_ALLOCATION_ORDER: u8 = std.math.log2_int_ceil(
    u8,
    @sizeOf(std.SinglyLinkedList.Node)
);

/// Should just allocate whole page if cant fit atleast 2 per page
const MAX_ALLOCATION_ORDER: u8 = std.math.log2_int(
    u8,
    @intCast(common.PAGE_SIZE / 2)
);
