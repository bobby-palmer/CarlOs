//! Module of commonly used interfaces and constants

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

/// Recursively get parent of nested pointer
pub fn nestedFieldParentPtr(
    comptime T: type,
    comptime field_names: []const []const u8,
    field_ptr: *anyopaque,
) *T {
    std.debug.assert(field_names.len > 0);

    if (field_names.len == 1) {
        return @fieldParentPtr(field_names[0], @as(*@FieldType(T, field_names[0]), @alignCast(@ptrCast(field_ptr))));
    } else {
        const tp = nestedFieldParentPtr(@FieldType(T, field_names[0]), field_names[1..], field_ptr);
        return @fieldParentPtr(
            field_names[0],
            tp
        );
    }
}
