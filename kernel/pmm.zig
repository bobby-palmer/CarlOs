//! Global free page buddy allocator, and metadata manager

const std = @import("std");
const common = @import("common.zig");
const Spinlock = @import("Spinlock.zig");

/// Similar to linux struct Page {} this is used to hold various metadatas
/// depending on what component owns the page
pub const Page = struct {

};

pub fn addRam() void {

}

pub fn alloc(order: u8) !*Page {

}

pub fn free(page: *Page, order: u8) void {

}
