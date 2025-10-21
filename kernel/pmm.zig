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

pub fn init(ram: []const MemoryRegion, _: []const MemoryRegion) void {
    std.debug.assert(!initialized);
    std.debug.assert(ram.len > 0);

    initialized = true;
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
