//! Library code that isn't attached to a specific OS component

pub const Spinlock = @import("common/Spinlock.zig");
pub const util = @import("common/util.zig");
pub const riscv = @import("common/riscv.zig");


// TODO remove this when pagetable is good, hacky workaround
const _RAM_START: usize = 0x80000000;
const _VIRTUAL_RAM_START: usize = 0xffffffffc0000000;

pub fn virtToPhys(virtual: usize) usize {
    return virtual - _VIRTUAL_RAM_START + _RAM_START;
}
