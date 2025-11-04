//! Global free-page allocator, built on the buddy system. 

const std = @import("std");
const common = @import("common.zig");

/// Max allocation is 2^10 pages
pub const MAX_ORDER: u8 = 10;

/// NOT MULTI-CPU SAFE, make all calls to this in the boot strap code
pub fn addRam(ram: common.MemorySpan, reserved: []const common.MemorySpan) void {
    _ = ram;
    _ = reserved;
    unreachable;
}

/// Allocate 2^order phyical pages
pub fn alloc(order: u8) error{OutOfMemory}!*Page {
    _ = order;
    unreachable;
}

/// Alloc(order: 0) for convenience
pub fn allocPage() error{OutOfMemory}!*Page {
    return alloc(0);
}

/// Free the allocated pages, page must be the page returned by alloc(...) but
/// it is ok to look up the page pointer by address
pub fn free(page: *Page) void {
    _  = page;
    unreachable;
}

/// Return the page that starts on a given address if it exists
pub fn lookupPage(base_addr: usize) ?*Page {
    _ = base_addr;
    unreachable;
}

/// Page metadata storage
const Page = struct {
    flags: struct {
        free: u1,
        reserved: u1,
        is_head: u1,
    },

    ppn: u44,
};
