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
    for (ram) |entry| {
        var index = common.pageUp(entry.base_addr);
        const end = common.pageDown(entry.base_addr + entry.length);

        while (index < end) : (index += 1) {
            clear(index);
        }
    }

    // reserved
    for (reserved) |entry| {
        var index = common.pageDown(entry.base_addr);
        const end = common.pageUp(entry.base_addr + entry.length);

        while (index < end) : (index += 1) {
            set(index);
        }
    }

    // reserve bitmap
    {
        var index = common.pageDown(bitmap.ptr);
        const end = common.pageUp(bitmap.ptr + bitmap.length);

        while (index < end) : (index += 1) {
            set(index);
        }
    }
}

/// Allocate "len" contiguous pages. len must be >0
pub fn allocFrames(len: usize) PmmError!usize {
    std.debug.assert(initialized);
    std.debug.assert(len > 0);

    // TODO not sure how to make this fast
    unreachable;
}

/// Allocate 1 page
pub fn allocFrame() PmmError!usize {
    return allocFrames(1);
}

/// Mark "len" pages starting from "base_addr" as free
pub fn freeFrames(base_addr: usize, len: usize) void {
    std.debug.assert(initialized);
    std.debug.assert(std.mem.isAligned(base_addr, common.PAGE_SIZE));

    const first_page = common.pageDown(base_addr);

    for (0..len) |offset| {
        std.debug.assert(isSet(first_page + offset));
        clear(first_page + offset);
    }
}

/// Make page starting at "base_addr" as free
pub fn freeFrame(base_addr: usize) void {
    freeFrames(base_addr, 1);
}

fn set(page: u64) void {
    std.debug.assert(initialized);
    std.debug.assert(isManaged(page));

    const offset = page - base_page;
    const word_idx = offset / 64;
    const bit_idx = offset % 64;

    bitmap[word_idx] |= (1 << bit_idx);
}

fn clear(page: u64) void {
    std.debug.assert(initialized);
    std.debug.assert(isManaged(page));

    const offset = page - base_page;
    const word_idx = offset / 64;
    const bit_idx = offset % 64;

    bitmap[word_idx] &= ~(1 << bit_idx);
}

fn isSet(page: u64) bool {
    std.debug.assert(initialized);
    std.debug.assert(isManaged(page));

    const offset = page - base_page;
    const word_idx = offset / 64;
    const bit_idx = offset % 64;

    return (bitmap[word_idx] >> bit_idx) & 1 == 1;
}

/// Return true if page is managed by the pmm
fn isManaged(page: u64) bool {
    std.debug.assert(initialized);
    return base_page <= page and page < endPage();
}

/// First page after pages in bitmap
fn endPage() u64 {
    return base_page + bitmap.len * 64;
}

var initialized = false;
var base_page: u64 = undefined;
var bitmap: []u64 = undefined;
