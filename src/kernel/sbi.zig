pub fn readCsr(comptime reg: []const u8) u64 {
    return asm volatile ("csrr %[result], " ++ reg
        : [result] "=r" (-> u64),
    );
}

pub fn writeCsr(comptime reg: []const u8, val: u64) void {
    asm volatile (
        "csrw " ++ reg ++ ", %[value]"
        :
        : [value] "r" (val)
    );
}

pub fn putChar(ch: u8) void {
    asm volatile(
        "ecall"
        :
        : [ch]     "{a0}" (ch),
          [id]     "{a6}" (0),
          [legacy] "{a7}" (1),
        : "memory", "a0", "a1"
    );
}
