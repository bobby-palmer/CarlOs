pub const Spinlock = @import("common/Spinlock.zig");
pub const util = @import("common/util.zig");
pub const riscv = @import("common/riscv.zig");
pub const constants = @import("common/constants.zig");


const _RAM_START: usize = 0x80000000;
const _VIRTUAL_RAM_START: usize = 0xffffffffc0000000;
const VMA_OFFSET = _VIRTUAL_RAM_START - _RAM_START;

/// Phyical address
pub const Paddr = struct { 
    paddr: usize,

    pub fn fromVaddr(addr: usize) Paddr {
        return Paddr {.paddr = addr - VMA_OFFSET};
    }

    pub fn getVaddr(self: *const Paddr) usize {
        return self.paddr + VMA_OFFSET;
    }
};
