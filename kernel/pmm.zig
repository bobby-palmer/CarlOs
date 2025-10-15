const std = @import("std");

const PAGE_ORD = 12;

pub const PAGE_SIZE: u64 = 1 << PAGE_ORD; // 4 KB

pub const MemoryBlock = struct {
    address: u64,
    size: u64,
}; // MemoryBlock

var base_page: u64 = undefined;
var bitmap: []u64 = undefined;

fn pageUp(address: u64) u64 {
    return (address >> PAGE_ORD) + 
        if (address & (PAGE_SIZE - 1) > 0) {
            1;
        } else {
            0;
        };
}

fn pageDown(address: u64) u64 {
    return address >> PAGE_ORD;
}

pub fn init(ram: []const MemoryBlock, reserved: []const MemoryBlock) void {

    if (ram.len == 0) {
        return;
    }

    var min_page: u64 = pageDown(ram[0].address);
    var max_page: u64 = pageUp(ram[0].address + ram[0].size);

    for (ram) |block| {
        min_page = @min(min_page, pageDown(block.address));
        max_page = @max(max_page, pageUp(block.address + block.size));
    }

    var max_reserved_page = min_page;

    for (reserved) |block| {
        max_reserved_page = @max(max_reserved_page, pageUp(block.address + block.size));
    }

    const N_LWORDS = ((max_page - min_page) + 63) / 64;

    base_page = min_page;
    bitmap = @as([*]u64, @ptrFromInt(max_reserved_page))[0..N_LWORDS];

    @memset(bitmap, 0); // initialize all pages to taken

    for (ram) |block| {
        var l = pageUp(block.address);
        const r = pageDown(block.address + block.size);

        while (l < r) {
            setFree(l);
            l += 1;
        }
    }

    for (reserved) |block| {
        var l = pageDown(block.address);
        const r = pageUp(block.address + block.size);

        while (l < r) {
            setTaken(l);
            l += 1;
        }
    }
} // init(...)

fn setFree(page: u64) void {
    const adj = page - base_page;

    const idx = adj / 64;
    const bidx = adj % 64;
    bitmap[idx] |= (1 << bidx);
} // setFree(...)

fn setTaken(page: u64) void {
    const adj = page - base_page;

    const idx = adj / 64;
    const bidx = adj % 64;
    bitmap[idx] &= ~(1 << bidx);
} // setTaken(...)
