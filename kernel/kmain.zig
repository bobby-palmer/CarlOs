export fn _start() linksection(".text.boot") callconv(.naked) noreturn {
    asm volatile (
        \\ li a0, 0x12345678
        \\ j kmain
    );
}

export fn kmain() noreturn {
    while (true) {}
}
