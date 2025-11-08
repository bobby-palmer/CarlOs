//! Process control block struct and utilities

const Process = @This();

const std = @import("std");
const common = @import("common.zig");
const vmm = @import("vmm.zig");
const riscv = common.riscv;

pid: u64,
trap_frame: *riscv.TrapFrame,
page_table: vmm.PageTablePointer,
kernel_stack_top: usize,
state: State,

pub const State = enum {
    Ready,
    Running,
    Waiting,
    Terminated,
};

pub fn init(alloc: std.mem.Allocator) !*Process {
    _ = alloc;
    unreachable;
}

pub fn destroy(self: *Process, alloc: std.mem.Allocator) void {
    _ = self;
    _ = alloc;
    unreachable;
}
