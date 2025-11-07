//! Global free-page allocator!

const std = @import("std");
const common = @import("common.zig");
const constants = common.constants;

/// Initialize phyical memory manager at boot. Should be called exactly once.
/// start and end addr should be phyical addresses
pub fn init(start_addr: common.Paddr, end_addr: common.Paddr) void {
    const start_page_addr = 
        std.mem.alignForward(usize, start_addr.paddr, constants.PAGE_SIZE); 

    const end_page_addr =
        std.mem.alignBackward(usize, end_addr.paddr, constants.PAGE_SIZE);

    var current_page_addr = start_page_addr;

    while (current_page_addr < end_page_addr) 
        : (current_page_addr += constants.PAGE_SIZE) {
        freePage(common.Paddr{.paddr = current_page_addr});
    }
}

/// Try to allocate a page a return its phyical start address. Page is not
/// guaranteed to be zeroed
pub fn allocPage() error{OutOfMemory}!common.Paddr {
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
pub fn freePage(start_addr: common.Paddr) void {
    if (!std.mem.isAligned(start_addr.paddr, constants.PAGE_SIZE)) {
        @panic("freePage(...) called on missaligned address");
    }

    lock.lock();
    defer lock.unlock();

    const node = 
        @as(*Node, @ptrFromInt(start_addr.getVaddr()));

    node.* = free_pages;
    free_pages = start_addr;
}

const Node = ?common.Paddr;
var lock = common.Spinlock{};
var free_pages: Node = null;
