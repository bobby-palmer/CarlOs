//! Kernel scoped slab allocator. Phyical memory manager (pmm) must be
//! initialized before using.

const std = @import("std");

pub const allocator = std.mem.Allocator {
    .ptr = undefined,
    .vtable = std.mem.Allocator.VTable {
        .alloc = alloc,
        .free = free,
    }
};

fn alloc(
    ctx: *anyopaque, 
    len: usize, 
    alignment: std.mem.Alignment,
    ret_addr: usize
) ?[*]u8 {
    _ = ctx;
    _ = len;
    _ = alignment;
    _ = ret_addr;
    return null;
}

fn free(
    ctx: *anyopaque, 
    memory: []u8, 
    alignment: std.mem.Alignment, 
    ret_addr: usize
) void {
    _ = ctx;
    _ = memory;
    _ = alignment;
    _ = ret_addr;
}

const Slab = struct {
    slab_list: ?*Slab,
    free_list: ?*anyopaque,
    inuse: usize,
};

const MemCache = struct {
    partial_slabs: ?*Slab,
    object_size: usize,
};
