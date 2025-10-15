const std = @import("std");

const PAGE_ORD = 12;

pub const PAGE_SIZE: u64 = 1 << PAGE_ORD; // 4 KB

pub const MemoryBlock = struct {
    address: u64,
    size: u64,
}; // MemoryBlock

// normalize pages relative to ram start address
var base_page: u64 = undefined; 

// bit array where 1 means free and 0 means taken page
var bitmap: []u64 = undefined; 

// return nearest page starting on or after address
fn pageUp(address: u64) u64 {
    return (address >> PAGE_ORD) + 
        if (address % PAGE_SIZE > 0) {
            1;
        } else {
            0;
        };
}

// return nearest page staring on or before address
fn pageDown(address: u64) u64 {
    return address >> PAGE_ORD;
}

const PpmError = error {
    InvalidAddress,
    DoubleFree,
}; // PpmError

/// Initialize physical memory manager
// TODO make this return error on failure
pub fn init(ram: []const MemoryBlock, reserved: []const MemoryBlock) void {

    if (ram.len == 0) {
        return;
    }

    var min_page: u64 = pageDown(ram[0].address);
    var max_page: u64 = pageUp(ram[0].address + ram[0].size);

    // get range of addresses we need to track
    for (ram) |block| {
        min_page = @min(min_page, pageDown(block.address));
        max_page = @max(max_page, pageUp(block.address + block.size));
    }

    var max_reserved_page = min_page;

    // get highest reserved block end
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
            // TODO set free
            l += 1;
        }
    }

    for (reserved) |block| {
        var l = pageDown(block.address);
        const r = pageUp(block.address + block.size);

        while (l < r) {
            // TODO set taken
            l += 1;
        }
    }
} // init(...)
