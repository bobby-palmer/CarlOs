//! Virtual memory manager using RISC-V Sv39

const std = @import("std");
const common = @import("common.zig");
const pmm = @import("pmm.zig");

/// Permission bits for mmu mapping
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
    G: u1 = 0,

    /// Accessed bit. Automatically set by the CPU whenever this memory address
    /// is accessed (IF, load, or store).
    A: u1 = 0,

    /// Dirty bit. Automatically set by the CPU whenever this memory address is
    /// written to (stores).
    D: u1 = 0,
};

/// All virtual addresses must be less than this.
pub const MAX_VA: usize = 1 << (9 + 9 + 9 + 12);

pub fn create() !*PageTable {
    const addr = try pmm.alloc(0);
    const ptr: *PageTable = @ptrFromInt(addr);

    ptr.* = .{}; // zero init the page table

    return ptr;
}

pub fn destroy(pt: *PageTable) void {
    for (pt.entries) |entry| {
        if (entry.flags.V == 1) {
            if (entry.flags.R | entry.flags.W | entry.flags.X == 0) {
                destroy(@ptrFromInt(common.addrOfPage(entry.ppn)));
            } else {
                // phyical page mapping. Separate function?
                unreachable;
            }
        }
    }

    pmm.free(@intFromPtr(pt), 0);
}

pub fn map(pt: *PageTable, vaddr: usize, paddr: usize, flags: Flags) !void {
    std.debug.assert(std.mem.isAligned(vaddr, common.PAGE_SIZE));
    std.debug.assert(std.mem.isAligned(paddr, common.PAGE_SIZE));
    _ = pt;
    _ = flags;
    unreachable;
}

pub fn unmap(pt: *PageTable, vaddr: usize) !void {
    _ = pt;
    _ = vaddr;
    unreachable;
}

/// Get the page table entry for vaddr if it exists
fn walk(pt: *PageTable, vaddr: usize) ?*PageTableEntry {

}

/// Sv39 page table entry
const PageTableEntry = packed struct {
    flags: Flags,
    /// Can have arbitrary data
    rsw: u2,
    ppn: u44,
    /// Ignore (reserved for larger addresses)
    rsw2: u10,
};

const PageTable = struct {
    entries: [512]PageTableEntry,

    // Verify struct sizes
    comptime {
        std.debug.assert(@sizeOf(PageTable) == common.PAGE_SIZE);
    }
};
