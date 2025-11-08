pub const Spinlock = @import("common/Spinlock.zig");
pub const util = @import("common/util.zig");
pub const riscv = @import("common/riscv.zig");
pub const constants = @import("common/constants.zig");

/// Phyical address struct
pub const Paddr = struct { 
    paddr: usize,

    pub fn getVaddr(self: *const Paddr) usize {
        return self.paddr + constants.VMA_OFFSET;
    }

    pub fn fromPpn(ppn: usize) Paddr {
        return Paddr { .paddr = constants.PAGE_SIZE * ppn };
    }

    /// Return phyical page number for the page that contains this address
    /// (basically round down)
    pub fn getPpn(self: *const Paddr) usize {
        return self.paddr / constants.PAGE_SIZE;
    }
};

/// Return true if this address is in the kernels address space
pub fn isKernelAddress(vaddr: usize) bool {
    return (vaddr >> 47) > 0;
}

/// Return bit mask with lower bits set
pub fn bitMask(bits: u8) usize {
    return (@as(usize, 1) << @intCast(bits)) - 1;
}

/// Ceiling division for unsigned number types
pub fn divCeil(num: anytype, denom: @TypeOf(num)) @TypeOf(num) {
    return (num + denom - 1) / denom;
}
