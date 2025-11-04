//! Simple struct to represent a range of addresses

const MemorySpan = @This();

start: usize,
end: usize,

pub fn len(self: *const MemorySpan) usize {
    return self.end - self.start;
}

/// Slice over the bytes in the region
pub fn slice(self: *const MemorySpan) []u8 {
    return @as([*]u8, @ptrFromInt(self.start))[0..self.len()];
}
