//! Virtual memory manager (vmm) module implementing Sv39 paging RISC-V

const std = @import("std");
const Pmm = @import("pmm.zig");

/// MMU Permission bits and state tracking
pub const Flags = packed struct {

    /// Valid bit. If this is 0, then the entire entry is invalid. This will
    /// cause the MMU to throw a page fault
    V: u1,

    /// Read bit. If this bit is 1, then we are permitted to read from this
    /// memory address. Otherwise, the MMU will cause a page fault on loads.
    R: u1,

    /// Write bit. If this bit is 1, then we are permitted to write to this
    /// memory address. Otherwise, the MMU will cause a page fault on stores.
    W: u1,

    /// Execute bit. If this bit is 1, then the CPU is permitted to execute an
    /// instruction fetch (IF) at this memory address. Otherwise, the MMU will
    /// cause a page fault on IF.
    X: u1,

    /// User bit. If this bit is 1, then a user-application is permitted to RWX
    /// (depending on the bits above) at this memory location. If this bit is
    /// 0, the only the operating system can RWX at this memory location.
    U: u1,

    /// Global bit. This memory address is used for more than one application,
    /// so this is a hint to the cache policy. In other words, don’t evict it
    /// when we switch programs.
    G: u1,

    /// Accessed bit. Automatically set by the CPU whenever this memory address
    /// is accessed (IF, load, or store).
    A: u1,

    /// Dirty bit. Automatically set by the CPU whenever this memory address is
    /// written to (stores).
    D: u1,
};

/// Map virtual address to phyical address
pub fn mapPage(_: *PageTable, _: usize, _: usize, _: Flags) void {
    unreachable; // TODO
}

/// Page table entry in Sv39 paging for RISC-V 64
const Sv39Pte = packed struct {

    flags: Flags,

    /// Reserved for Software. The operating system can put whatever it wants
    /// in here.
    reserved0: u2,

    ppn: u44,

    /// Reserved for bigger entries (such as SV48 and SV56).
    reserved1: u10,

    fn isLeaf(self: *const @This()) bool {
        return (
            self.flags.R == 1 or
            self.flags.W == 1 or
            self.flags.X == 1
        );
    }
};

const PageTable = struct {
    entries: [512]Sv39Pte
};
