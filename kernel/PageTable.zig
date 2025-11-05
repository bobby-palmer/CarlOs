//! Riscv sv39 virtual paging handler. Following
//! https://marz.utk.edu/my-courses/cosc130/lectures/virtual-memory/
const PageTable = @This();

const std = @import("std");
const pmm = @import("pmm.zig");
const common = @import("common.zig");
const constants = common.constants;

entries: [512]Pte,

/// Permission flags for virtual memory mapping
pub const Flags = packed struct {
    /// Valid bit. If this is 0, then the entire entry is invalid. This will
    /// cause the MMU to throw a page fault.
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

    fn nonLeaf() Flags {
        return Flags {
            .V = 1,
            .R = 0,
            .W = 0,
            .X = 0,
            .U = 0,
            .G = 0,
            .A = 0,
            .D = 0,
        };
    }
};

/// Create a page level with no mappings
pub fn create() !*PageTable {
    const base_addr = try pmm.allocPage();
    const pt: *PageTable = @intFromPtr(base_addr);

    for (pt.entries) |*entry| {
        entry.flags.V = 0;
    }
}

/// Recursively free page table, not touching leaf mappings
pub fn destroy(self: *PageTable) void {
    for (self.entries) |*entry| {
        if (entry.flags.V) {
            if (entry.flags.R | entry.flags.W | entry.flags.X == 1) {
                @panic("destroy called on pagetable with mapped page(s)");
            } else {
                const pt_addr: usize = constants.PAGE_SIZE * entry.ppn;
                const child: *PageTable = @ptrFromInt(pt_addr);
                destroy(child);
            }
        }
    }

    pmm.freePage(@intFromPtr(self));
}

pub fn mapPage(self: *PageTable, vaddr: usize, paddr: usize, flags: Flags) error{OutOfMemory}!void {
    const pte = try self.walkAndAllocate(vaddr);
    pte.flags = flags;
    pte.ppn = paddr / constants.PAGE_SIZE;
}

pub fn unmapPage(self: *PageTable, vaddr: usize) error{NotMapped}!void {
    const pte = self.walk(vaddr) orelse return error.NotMapped;
    pte.flags.V = 0;
}

/// Return phyical address vaddr is mapped to if there is a valid mapping
pub fn getPaddr(self: *PageTable, vaddr: usize) ?usize {
    const pte = self.walk(vaddr) orelse return null;

    if (pte.flags.V == 1) {
        return pte.ppn * constants.PAGE_SIZE;
    } else {
        return null;
    }
}

/// Sv39 page table entry
const Pte = packed struct {
    flags: Flags,
    rsw: u2,
    ppn: u44,
    rsw2: u10,
};

/// Get page table entry for given vaddr or null if it doesnt exist
fn walk(self: *PageTable, vaddr: usize) ?*Pte {
    var pt = self;

    for ([_]u8{2, 1}) |level| {
        const entry = &pt.entries[vpn(vaddr, level)];

        if (entry.flags.V == 1) {
            const child_addr: usize = constants.PAGE_SIZE * entry.ppn;
            pt = @ptrFromInt(child_addr);
        } else {
            return null;
        }
    }

    return &pt.entries[vpn(vaddr, 0)];
}

/// Get page table entry for given vaddr, allocting along the way
fn walkAndAllocate(self: *PageTable, vaddr: usize) error{OutOfMemory}!*Pte {
    var pt = self;

    for ([_]u8{2, 1}) |level| {
        const entry = &pt.entries[vpn(vaddr, level)];

        if (entry.flags.V == 0) {
            const new_child = try create();
            entry.flags = Flags.nonLeaf();
            entry.ppn = @intFromPtr(new_child) / constants.PAGE_SIZE;
        }

        const child_addr: usize = constants.PAGE_SIZE * entry.ppn;
        pt = @ptrFromInt(child_addr);
    }

    return &pt.entries[vpn(vaddr, 0)];
}

fn vpn(vaddr: usize, level: u8) usize {
    return 0x1FF & (vaddr >> (12 + 9 * level));
}
