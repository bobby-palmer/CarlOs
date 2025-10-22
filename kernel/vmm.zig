//! Virtual memory manager (vmm) module implementing Sv39 paging RISC-V

const std = @import("std");
const pmm = @import("pmm.zig");
const common = @import("common.zig");

/// MMU Permission bits and state tracking
pub const Flags = packed struct {

    /// Valid bit. If this is 0, then the entire entry is invalid. This will
    /// cause the MMU to throw a page fault
    V: u1 = 1,

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
    A: u1 = 0,

    /// Dirty bit. Automatically set by the CPU whenever this memory address is
    /// written to (stores).
    D: u1 = 0,
};

/// Map virtual page to phyical page
pub fn mapPage(pt: *PageTable, vaddr: usize, paddr: usize, flags: Flags) pmm.Error!void {
    std.debug.assert(std.mem.isAligned(vaddr, common.PAGE_SIZE));
    std.debug.assert(std.mem.isAligned(paddr, common.PAGE_SIZE));

    const pte = try walkAndAllocate(pt, vaddr);

    if (pte.flags.V == 1) {
        @panic("Double map virtual page");
    }

    pte.flags = flags;
    pte.ppn = @intCast(common.pageDown(paddr));
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
};

const PageTable = struct {
    entries: [512]Sv39Pte
};

/// get page table entry for virtual address, allocating levels
/// along the way if they dont exist
fn walkAndAllocate(pt: *PageTable, vaddr: usize) pmm.Error!*Sv39Pte {
    std.debug.assert(std.mem.isAligned(vaddr, common.PAGE_SIZE));

    var current_page_table = pt;
    const first_two_vpns = [_]usize{vpn(vaddr, 2), vpn(vaddr, 1)};

    for (first_two_vpns) |offset| {
        const pte = &current_page_table.entries[offset];

        if (pte.flags.V == 0) {
            pte.ppn = @intCast(try pmm.allocFrame());
            pte.flags.V = 1;
        }

        current_page_table = @ptrFromInt(pte.ppn);
    }

    return &current_page_table.entries[vpn(vaddr, 0)];
}

fn vpn(vaddr: usize, index: u2) usize {
    return (vaddr >> (12 + index * 9)) & 0x1FF;
}
