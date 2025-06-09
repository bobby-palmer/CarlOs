const sbi = @import("sbi.zig");

pub fn print(str: [] const u8) void {
    for (str) |ch| {
        sbi.putChar(ch);
    }
}

pub fn printNull(str: [*:0] const u8) void {
    var i: usize = 0;
    while (str[i] != 0) {
        sbi.putChar(str[i]);
        i += 1;
    }
}

pub fn printU32(num: u32) void {
    if (num == 0) {
        sbi.putChar('0');
    } else {
        var in = num;
        var base: u32 = 1;

        while (base * 10 < in) 
            base *= 10;

        while (base > 0) {
            sbi.putChar(@intCast('0' + in / base));
            in %= base;
            base /= 10;
        }
    }
}

pub fn printHex(num: u64) void {
    print("0x");

    const hex_digits = "0123456789abcdef";

    var digits: [16] u8 = undefined;
    for (0..digits.len) |i| {
        digits[i] = hex_digits[@intCast((num >> @intCast(4 * i)) & 0xF)];
    }

    var i = digits.len;
    while (i > 0) {
        i -= 1;
        sbi.putChar(digits[i]);
    }
}
