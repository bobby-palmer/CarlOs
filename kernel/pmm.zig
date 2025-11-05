//! Global free-page allocator!

const std = @import("std");
const common = @import("common.zig");

/// Initialize phyical memory manager at boot. Should be called exactly once
pub fn init(start_addr: usize, end_addr: usize) void {
    const start_page_addr = 
        std.mem.alignForward(usize, start_addr, common.constants.PAGE_SIZE); 

    const end_page_addr =
        std.mem.alignBackward(usize, end_addr, common.constants.PAGE_SIZE);

    var current_page_addr = start_page_addr;

    while (current_page_addr < end_page_addr) 
        : (current_page_addr += common.constants.PAGE_SIZE) {
        freePage(current_page_addr);
    }
}

/// Try to allocate a page a return its start address. 
/// Page is not guaranteed to be zeroed
pub fn allocPage() error{OutOfMemory}!usize {
    lock.lock();
    defer lock.unlock();

    if (free_pages.popFirst()) |node| {
        return @intFromPtr(node);
    } else {
        return error.OutOfMemory;
    }
}

/// Free a page starting at 'start_addr'
pub fn freePage(start_addr: usize) void {
    if (!std.mem.isAligned(start_addr, common.constants.PAGE_SIZE)) {
        @panic("freePage(...) called on missaligned address");
    }

    lock.lock();
    defer lock.unlock();

    const node = 
        @as(*std.SinglyLinkedList.Node, @ptrFromInt(start_addr));

    node.* = .{};
    free_pages.prepend(node);
}

var lock = common.Spinlock{};
var free_pages = std.SinglyLinkedList{};
