//! Process control block!

const Process = @This();

const std = @import("std");
const common = @import("common.zig");

pid: u64,

pub fn create(allocator: std.mem.Allocator, entry: fn () void) !*Process {
    _ = entry; // TODO

    const pcb = try allocator.create(@This());
    errdefer allocator.destroy(pcb);

    pcb.pid = next_pid.fetchAdd(1, .seq_cst);

    return pcb;
}

pub fn destroy(self: *const Process, allocator: std.mem.Allocator) void {
    allocator.destroy(self);
}

var next_pid: std.atomic.Value(u64) = 1;
