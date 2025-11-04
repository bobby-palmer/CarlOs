//! Utility convenience functions module

const std = @import("std");

/// Recursively get parent of nested pointer
pub fn nestedFieldParentPtr(
    comptime T: type,
    comptime field_names: []const []const u8,
    field_ptr: *anyopaque,
) *T {
    comptime { std.debug.assert(field_names.len > 0); }

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
