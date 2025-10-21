//! Phyical memory manager (pmm) module. This module handles tracking free and
//! used phyical pages. It must be initialized exactly once!

const std = @import("std");
const constants = @import("constants.zig");

// Interface

pub const MemoryRegion = struct {
    base_addr: usize,
    length: usize,
};

const PmmError = error {
    OutOfMemory
};

pub fn init(_: []const MemoryRegion, _: []const MemoryRegion) void {

}

/// Allocate "len" contiguous pages
pub fn allocFrames(_: usize) PmmError!usize {
    std.debug.assert(initialized);
    unreachable;
}

/// Allocate 1 page
pub fn allocFrame() PmmError!usize {
    return allocFrames(1);
}

/// Mark "len" pages starting from "base_addr" as free
pub fn freeFrames(_: usize, _: usize) void {
    std.debug.assert(initialized);
    unreachable;
}

/// Make page starting at "base_addr" as free
pub fn freeFrame(base_addr: usize) void {
    freeFrames(base_addr, 1);
}

// Internal

var initialized = false;
var base_page: u64 = undefined;
var bitmap: []u64 = undefined;
