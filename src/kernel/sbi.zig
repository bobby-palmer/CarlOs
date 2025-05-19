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
