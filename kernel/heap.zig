//! Kernel scoped slab allocator. TODO

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

/// Header for a region of contiguous pages
const BlockHeader = struct {
    next: ?*BlockHeader,
    used: usize,
};
