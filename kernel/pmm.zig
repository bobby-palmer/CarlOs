//! Global free-page allocator! TODO add DMA regions

const std = @import("std");
const common = @import("common.zig");

pub fn init(start_addr: usize, end_addr: usize) void {
    const start_page_addr = 
        std.mem.alignForward(usize, start_addr, common.constants.PAGE_SIZE); 
    const end_page_addr =
        std.mem.alignBackward(usize, end_addr, common.constants.PAGE_SIZE);

    for (start_page_addr..end_page_addr) |page_addr| {
        free(page_addr);
    }
}

pub fn allocPage() error{OutOfMemory}!usize {
    lock.lock();
    defer lock.unlock();

    if (free_pages.popFirst()) |node| {
        return @intFromPtr(node);
    } else {
        return error.OutOfMemory;
    }
}

pub fn free(start_addr: usize) void {
    lock.lock();
    defer lock.unlock();

    const node = 
        @as(*std.SinglyLinkedList.Node, @ptrFromInt(start_addr));

    node.* = .{};
    free_pages.prepend(node);
}

var free_pages = std.SinglyLinkedList{};
var lock = common.Spinlock{};
