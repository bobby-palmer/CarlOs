//! Riscv sv48 virtual paging handler

const pmm = @import("pmm.zig");
const common = @import("common.zig");
const constants = common.constants;

/// Permission flags for virtual memory mapping
pub const Flags = packed struct {
    /// Valid bit. If this is 0, then the entire entry is invalid. This will
    /// cause the MMU to throw a page fault.
    V: u1 = 1,
    /// Read bit. If this bit is 1, then we are permitted to read from this
    /// memory address. Otherwise, the MMU will cause a page fault on loads.
    R: u1 = 0,
    /// Write bit. If this bit is 1, then we are permitted to write to this
    /// memory address. Otherwise, the MMU will cause a page fault on stores.
    W: u1 = 0,
    /// Execute bit. If this bit is 1, then the CPU is permitted to execute an
    /// instruction fetch (IF) at this memory address. Otherwise, the MMU will
    /// cause a page fault on IF.
    X: u1 = 0,
    /// User bit. If this bit is 1, then a user-application is permitted to RWX
    /// (depending on the bits above) at this memory location. If this bit is
    /// 0, the only the operating system can RWX at this memory location.
    U: u1 = 0,
    /// Global bit. This memory address is used for more than one application,
    /// so this is a hint to the cache policy. In other words, don’t evict it
    /// when we switch programs.
    G: u1 = 0,
    /// Accessed bit. Automatically set by the CPU whenever this memory address
    /// is accessed (IF, load, or store).
    A: u1 = 0,
    /// Dirty bit. Automatically set by the CPU whenever this memory address is
    /// written to (stores).
    D: u1 = 0,

    fn isLeaf(self: *const Flags) bool {
        return self.R | self.W | self.X == 1;
    }
};

/// Extract the currently active pagetable phyical address
pub fn getCurrentPt() common.Paddr {
    const satp = common.riscv.readCSR("satp");
    const ppn = satp & ((@as(usize, 1) << 44) - 1); // bottom 44 bits
    return common.Paddr.fromPpn(ppn);
}

/// Look up phyical mapping of vaddr if it exists
pub fn translate(pt: common.Paddr, vaddr: usize) ?common.Paddr {
    var current_pt: *PageTable = @ptrFromInt(pt.getVaddr());

    for (&[_]u8 {3, 2, 1, 0}) |lvl| {
        const entry = &current_pt.entries[vpn(vaddr, lvl)];

        if (entry.flags.V == 0) return null;

        const child = common.Paddr.fromPpn(entry.ppn);

        if (entry.flags.isLeaf()) {
            const offset = vaddr & common.bitMask(12 + 9 * lvl);
            return common.Paddr{ .paddr = child.paddr + offset };
        }

        current_pt = @ptrFromInt(child.getVaddr());
    }

    unreachable;
}

/// Sv48 page table entry
const Pte = packed struct {
    flags: Flags,
    rsw: u2,
    ppn: u44,
    rsw2: u10,
};

const PageTable = struct {
    entries: [512]Pte,
};

fn vpn(vaddr: usize, level: u8) usize {
    return 0x1FF & (vaddr >> @intCast(12 + 9 * level));
}
