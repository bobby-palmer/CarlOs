//! Slub based heap allocator

const Heap = @This();

const std = @import("std");
const common = @import("common.zig");
const pmm = @import("pmm.zig");
const Spinlock = @import("Spinlock.zig");

lock: Spinlock = .{},
caches: 
    [MAX_ALLOCATION_ORDER - MIN_ALLOCATION_ORDER + 1]std.SinglyLinkedList = .{},

fn alloc(
    self: *anyopaque, 
    len: usize, 
    alignment: std.mem.Alignment, 
    ret_addr: usize) ?[*]u8 {
    
    _ = ret_addr;

    const this: *Heap = @ptrCast(self);
    const bytes = getAllocationOrder(len, alignment);

    if (bytes > MAX_ALLOCATION_ORDER) {

        const pages = getPageOrder(bytes);
        const page = pmm.alloc(pages) catch return null;
        return @ptrCast(page.startAddr());

    } else {
        unreachable;
    }
}

fn free(
    self: *anyopaque, 
    memory: []u8, 
    alignment: std.mem.Alignment, 
    ret_addr: usize) void {

    _ = ret_addr;

    const this: *Heap = @ptrCast(self);
    const bytes = getAllocationOrder(memory.len, alignment);

    if (bytes > MAX_ALLOCATION_ORDER) {

        const page = pmm.pageOfAddress(@intFromPtr(memory.ptr)) orelse unreachable;
        pmm.free(page);

    } else {
        unreachable;
    }
}

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

    if (page_order >= byte_order) {
        return 0;
    } else {
        return byte_order - page_order;
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
