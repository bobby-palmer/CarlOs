const std = @import("std");

const Bitmap = @This();

pub const BitmapError = error {
    OutOfRange,
    DoubleSet,
    DoubleReset,
};

/// Initialize bitmap at the first 64 bit aligned address >= buffer_address
pub fn init(buffer_address: usize, bit_count: usize) Bitmap {
    const aligned = std.mem.alignForward(usize, buffer_address, @alignOf(u64));
    const buffer = @as([*]u64, @intFromPtr(aligned));

    // Round up number of long words needed (u64)
    const n_lwords = (63 + bit_count) / 64;
    @memset(buffer[0..n_lwords], 0);

    return Bitmap {
        .data = buffer,
        .bit_count = bit_count,
    };
}

/// Return true if bit index is set to 1
pub fn isSet(self: *const Bitmap, idx: usize) BitmapError!bool {
    if (idx >= self.bit_count) {
        return BitmapError.OutOfRange;
    }

    const arr_idx, const bit_idx = indexOf(idx);
    return (self.data[arr_idx] >> bit_idx) & 1 == 1;
}

pub fn setBit(self: *const Bitmap, idx: usize) BitmapError!void {
    if (idx >= self.bit_count) {
        return BitmapError.OutOfRange;
    }
}

/// returns {arr_idx, bit_idx} for given bit index
fn indexOf(idx: usize) struct {usize, usize} {
    return .{idx / 64, idx % 64};
}

data: [*]u64,
bit_count: usize,
