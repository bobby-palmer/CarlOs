//! Global free page manager. 
//!
//! TODO :
//! - Add a contiguous portion to the manager and add api for allocating
//!   contiguous ram

const std = @import("std");
const common = @import("common.zig");
const Spinlock = @import("Spinlock.zig");

pub fn addRam(start: usize, end: usize) void {
    lock.lock();
    defer lock.unlock();

    var current_page = common.pageUp(start);
    const end_page = common.pageDown(end);

    while (current_page < end_page) : (current_page += 1) {

        const addr = common.addrOfPage(current_page);
        const node: *std.SinglyLinkedList.Node = @ptrFromInt(addr);

        freelist.prepend(node);
        num_free_pages += 1;

    }
}

pub fn allocPage() error{OutOfMemory}!usize {
    lock.lock();
    defer lock.unlock();

    if (freelist.popFirst()) |node| {

        num_free_pages -= 1;
        return @intFromPtr(node);

    } else {
        return error.OutOfMemory;
    }
}

pub fn freePage(addr: usize) void {
    const node: *std.SinglyLinkedList.Node = @ptrFromInt(addr);
    freelist.prepend(node);
    num_free_pages += 1;
}

pub fn getNumFree() usize {
    return num_free_pages;
}

var freelist: std.SinglyLinkedList = .{};
var num_free_pages: usize = 0;
var lock: Spinlock = .{};
