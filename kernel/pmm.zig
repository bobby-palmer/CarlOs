//! Phyical memory manager (pmm) module. This module handles tracking free and
//! used phyical pages. It must be initialized exactly once!

const std = @import("std");
const common = @import("common.zig");

pub const MemoryRegion = struct {
    base_addr: usize,
    length: usize,
};

const PmmError = error {
    OutOfMemory
};

pub fn init(ram: []const MemoryRegion, reserved: []const MemoryRegion) void {
    std.debug.assert(!initialized);
    std.debug.assert(ram.len > 0);

    // at the very least kernel must be reserved
    std.debug.assert(reserved.len > 0);

    // Collect state
    var min_page = common.pageDown(ram[0].base_addr);
    var max_page = common.pageUp(ram[0].base_addr + ram[0].length);

    for (ram) |entry| {
        min_page = @min(min_page, common.pageDown(entry.base_addr));
        max_page = @max(
            max_page, 
            common.pageUp(entry.base_addr + entry.length)
        );
    }

    var page_after_reserved = common.pageUp(reserved[0].base_addr +
        reserved[0].length);

    for (reserved) |entry| {
        page_after_reserved = @max(
            page_after_reserved,
            common.pageUp(entry.base_addr + entry.length)
        );
    }

    // Init everything to taken
    initialized = true;
    base_page = min_page;

    const pages = (max_page - min_page);
    const lwords = (pages / 64);
    const bmap_start = @as([*]u64, @ptrFromInt(common.addrOfPage(page_after_reserved)));

    bitmap = bmap_start[0..lwords];

    // Set all bits to high (taken)
    @memset(bitmap, (1 << 64) - 1);

    // free ram
    // TODO
    // reserved
    // TODO
    // reserve bitmap
    // TODO
}

/// Allocate "len" contiguous pages. len must be >0
pub fn allocFrames(len: usize) PmmError!usize {
    std.debug.assert(initialized);
    std.debug.assert(len > 0);

    unreachable;
}

/// Allocate 1 page
pub fn allocFrame() PmmError!usize {
    return allocFrames(1);
}

/// Mark "len" pages starting from "base_addr" as free
pub fn freeFrames(base_addr: usize, _: usize) void {
    std.debug.assert(initialized);
    std.debug.assert(std.mem.isAligned(base_addr, common.PAGE_SIZE));

    unreachable;
}

/// Make page starting at "base_addr" as free
pub fn freeFrame(base_addr: usize) void {
    freeFrames(base_addr, 1);
}

var initialized = false;
var base_page: u64 = undefined;
var bitmap: []u64 = undefined;
