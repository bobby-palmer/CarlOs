//! Global free-page allocator, for managing phyical memory!

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

/// Page metadata storage
const Page = struct {
    flags: struct {
        /// Is owned by the pmm
        free: u1,
        /// Should never be allocated or touched by any system
        reserved: u1,
        /// This is the beginning of either an allocated or reserved region
        is_head: u1,
    },
    /// Phyical page number (ppn)
    ppn: u44,
    /// if 'is_head == 1' this is the begining of 2^order pages
    order: u8,
};
