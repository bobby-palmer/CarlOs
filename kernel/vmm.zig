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

/// Bootstrap init (map the rest of the kernel)
pub fn init() !void {
    const ptp = getCurrentPt();
    const pt = deref(ptp);

    kernel_heap_map = try initEmptyPt();

    const entry = &pt.entries[vpn(constants.KHEAP_BASE, MAX_LEVEL)];
    entry.flags = .{};
    entry.ppn = @intCast(kernel_heap_map.getPpn());
}

/// Kernel mapping sections (exlcusing linear ram map)
var kernel_heap_map: PageTablePointer = undefined;

pub fn mapKernel(ptp: PageTablePointer) void {
    _ = ptp;
    unreachable;
}

/// Allocate a page table with no valid entries
pub fn initEmptyPt() !PageTablePointer {
    const paddr = try pmm.allocPage();

    const pt = deref(paddr);
    for (&pt.entries) |*entry| {
        entry.flags.V = 0;
    }

    return paddr;
}

/// Extract the currently active pagetable phyical address
pub fn getCurrentPt() PageTablePointer {
    const satp = common.riscv.readCSR("satp");
    const ppn = satp & common.bitMask(44);
    return common.Paddr.fromPpn(ppn);
}

pub fn setCurrentPt(ptp: PageTablePointer, asid: u16) void {
    const ppn = ptp.getPpn();
    const val: usize = (@as(usize, 9) << 60) | (asid << 44) | ppn;
    common.riscv.writeCSR("satp", val);
    common.riscv.fenceVma();
}

/// Look up phyical mapping of vaddr if it exists
pub fn translate(ptp: PageTablePointer, vaddr: usize) ?common.Paddr {
    var current_pt = deref(ptp);

    for (levels) |lvl| {
        const entry = &current_pt.entries[vpn(vaddr, lvl)];

        if (entry.flags.V == 0) return null;

        const child = common.Paddr.fromPpn(entry.ppn);

        if (entry.flags.isLeaf()) {
            const offset = vaddr & common.bitMask(12 + 9 * lvl);
            return common.Paddr{ .paddr = child.paddr + offset };
        }

        current_pt = @ptrFromInt(child.getVaddr());
    }

    @panic("Invalid page table");
}

pub fn mapPage(
    ptp: PageTablePointer, 
    vaddr: usize, 
    paddr: common.Paddr, 
    flags: Flags) !void {

    var current_pt = deref(ptp);

    for (levels) |lvl| {
        const entry = &current_pt.entries[vpn(vaddr, lvl)];

        if (lvl == 0) {

            if (entry.flags.V == 1) {
                return error.AlreadyMapped;
            } else {
                entry.flags = flags;
                entry.ppn = @intCast(paddr.getPpn());
                return;
            }

        } else {

            if (entry.flags.V == 0) {
                const child = try initEmptyPt();
                entry.flags = Flags{};
                entry.ppn = @intCast(child.getPpn());
            }

            const child = PageTablePointer.fromPpn(entry.ppn);
            current_pt = deref(child);

        }
    }

    common.riscv.fenceVma();
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

/// Wrapper struct for type safety
pub const PageTablePointer = common.Paddr;

fn deref(ptp: PageTablePointer) *PageTable {
    return @ptrFromInt(ptp.getVaddr());
}

const MAX_LEVEL: u8 = 3;
const levels: []const u8 = &[_]u8 {3, 2, 1, 0};

fn vpn(vaddr: usize, level: u8) usize {
    return 0x1FF & (vaddr >> @intCast(12 + 9 * level));
}
