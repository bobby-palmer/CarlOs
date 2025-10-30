//! RISC-V 64, Sv39 page table struct

const PageTable = @This();

const std = @import("std");
const common = @import("common.zig");

entries: [512]Pte,

/// All virtual addresses must be less than this
pub const MAX_VA: usize = 1 << (9 + 9 + 9 + 12);

/// Sv39 page table entry (pte)
pub const Pte = packed struct {

    /// Permission bits for mmu. Defaults to valid with no permissions
    pub const Flags = packed struct {
        /// Valid bit. If this is 0, then the entire entry is invalid. This will
        /// cause the MMU to throw a page fault
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
    };

    flags: Flags,
    rsw: u2,
    ppn: u44,
    rsw2: u10,
};

/// Construct a page table with all entries invalid
pub fn init(alloc: std.mem.Allocator) !*PageTable {
    const pt = try alloc.create(PageTable);

    // Initialize all entries to invalid
    for (pt.entries) |*entry| {
        entry.flags.V = 0;
    }

    return pt;
}

/// De-allocate all levels of page table. Requires that there are no mapped
/// leaf nodes!
pub fn deinit(self: *const PageTable, alloc: std.mem.Allocator) void {

    for (self.entries) |entry| {
        if (entry.flags.V == 1) {
            if (entry.flags.R | entry.flags.W | entry.flags.X == 1) {
                @panic("Try to deinit page table with leaf pages");
            } else {
                const child: *const PageTable 
                    = @intFromPtr(common.addrOfPage(entry.ppn));
                child.deinit(alloc);
            }
        }
    }

    alloc.destroy(self);
}

/// Look up the page table entry for vaddr or return null if there isnt one
pub fn getEntry(self: *const PageTable, vaddr: usize) ?*Pte {
    var pt = self;
    var level = 2;

    while (level > 0) : (level -= 1) {
        const pte = &pt.entries[vpn(vaddr, level)];

        if (pte.flags.V == 1) {
            pt = @ptrFromInt(common.addrOfPage(pte.ppn));
        } else {
            return null;
        }
    }

    return &pt.entries[vpn(vaddr, 0)];
}

/// Get entry for virtual address, allocating new page table levels if needed
pub fn getEntryAlloc(
    self: *PageTable, 
    alloc: std.mem.Allocator, 
    vaddr: usize) !*Pte {

    var pt = self;
    var level = 2;

    while (level > 0) : (level -= 1) {
        const pte = &pt.entries[vpn(vaddr, level)];

        if (pte.flags.V == 1) {

            pt = @ptrFromInt(common.addrOfPage(pte.ppn));

        } else {
            const next_level = try init(alloc);

            // TODO assert allignment
            pte.flags = .{};
            pte.ppn = common.pageDown(@intFromPtr(next_level));
            pt = next_level;

        }
    }

    return &pt.entries[vpn(vaddr, 0)];
}

/// Return phyical mapping of virtual address if it exists
pub fn vaddr2Paddr(self: *const PageTable, vaddr: usize) ?usize {
    const pte = getEntry(self, vaddr) orelse return null;

    // TODO assert leaf
    if (pte.flags.V == 1) {
        return common.addrOfPage(pte.ppn);
    } else {
        return null;
    }
}

inline fn vpn(vaddr: usize, level: usize) usize {
    return (vaddr >> @intCast(12 + level * 9));
}

// Verify struct sizing
comptime {
    std.debug.assert(@sizeOf(PageTable) == common.PAGE_SIZE);
}
