//! Global free-page allocator!

const std = @import("std");
const common = @import("common.zig");
const constants = common.constants;

pub const Paddr = struct {
    paddr: usize,

    /// Return kernel linear map vaddr for a given paddr
    pub fn getVaddr(self: *const Paddr) usize {
        return self.paddr + kernel_base;
    }

    /// Set the base of the kernel linear mapping (should be called once at boot)
    pub fn setKernelBase(base_addr: usize) void {
        kernel_base = base_addr;
    }

    /// Offset to the start of kernel linear mapping
    var kernel_base: usize = 0;
};

/// Initialize phyical memory manager at boot. Should be called exactly once.
/// start and end addr should be phyical addresses
pub fn init(start_addr: usize, end_addr: usize) void {
    const start_page_addr = 
        std.mem.alignForward(usize, start_addr, constants.PAGE_SIZE); 

    const end_page_addr =
        std.mem.alignBackward(usize, end_addr, constants.PAGE_SIZE);

    var current_page_addr = start_page_addr;

    while (current_page_addr < end_page_addr) 
        : (current_page_addr += constants.PAGE_SIZE) {
        freePage(current_page_addr);
    }
}

/// Try to allocate a page a return its phyical start address. Page is not
/// guaranteed to be zeroed
pub fn allocPage() error{OutOfMemory}!Paddr {
    lock.lock();
    defer lock.unlock();

    if (free_pages) |paddr| {
        const vaddr = paddr.getVaddr();
        free_pages = @as(*Node, @ptrFromInt(vaddr)).*;
        return paddr;
    } else {
        return error.OutOfMemory;
    }
}

/// Free a page starting at phyical address 'start_addr'
pub fn freePage(start_addr: Paddr) void {
    if (!std.mem.isAligned(start_addr.paddr, constants.PAGE_SIZE)) {
        @panic("freePage(...) called on missaligned address");
    }

    lock.lock();
    defer lock.unlock();

    const node = 
        @as(*Node, @ptrFromInt(start_addr.getVaddr()));

    node.* = free_pages;
    free_pages = node;
}

var lock = common.Spinlock{};

const Node = ?Paddr;
var free_pages: Node = null;
