//! Process control block struct and utilities TODO

const std = @import("std");
const common = @import("common.zig");
const vmm = @import("vmm.zig");
const riscv = common.riscv;

trap_frame: riscv.TrapFrame,
page_table: vmm.PageTablePointer,
kernel_stack_base: usize,
pid: u64,
parent: u64,
state: State,
node: std.SinglyLinkedList.Node,
user_stack_top: usize,
exit_code: i32,

pub const State = enum {
    Ready,
    Running,
    Waiting,
    Terminated,
};
