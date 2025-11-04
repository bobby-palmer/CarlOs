//! Module library code with no external dependencies. No deps is important to
//! be able to safely import at any level.

const std = @import("std");

pub const KB: u32 = 1 << 10;
pub const MB: u32 = 1 << 20;

pub const PAGE_SIZE: u32 = 4 * KB;

/// Return first page number that starts on or before addr
pub fn pageDown(addr: usize) u64 {
    return addr / PAGE_SIZE;
}

/// return first page that starts on or after addr
pub fn pageUp(addr: usize) u64 {
    return (addr + PAGE_SIZE - 1) / PAGE_SIZE;
}

/// return address of the start of page
pub fn addrOfPage(page: u64) usize {
    return page * PAGE_SIZE;
}

/// Generic memory block representation
pub const MemoryRegion = struct {
    start: usize,
    len: usize,

    pub fn end(self: *const MemoryRegion) usize {
        return self.start + self.len;
    }
};

/// Recursively get parent of nested pointer
pub fn nestedFieldParentPtr(
    comptime T: type,
    comptime field_names: []const []const u8,
    field_ptr: *anyopaque,
) *T {
    std.debug.assert(field_names.len > 0);

    if (field_names.len == 1) {
        return @fieldParentPtr(field_names[0], @as(*@FieldType(T,
                    field_names[0]), @alignCast(@ptrCast(field_ptr))));
    } else {
        const tp = nestedFieldParentPtr(@FieldType(T, field_names[0]),
            field_names[1..], field_ptr);
        return @fieldParentPtr(
            field_names[0],
            tp
        );
    }
}

/// Read a CSR register
pub inline fn readCSR(comptime reg: []const u8) u64 {
    var result: u64 = undefined;
    asm volatile ("csrr %[ret], " ++ reg
        : [ret] "=r" (result),
    );
    return result;
}

/// Write to a CSR register
pub inline fn writeCSR(comptime reg: []const u8, value: u64) void {
    asm volatile ("csrw " ++ reg ++ ", %[val]"
        :
        : [val] "r" (value),
    );
}

//-------------- Start new structure ==============
pub const Spinlock = @import("common/Spinlock.zig");
pub const riscv = @import("common/riscv.zig");
pub const constants = @import("common/constants.zig");
