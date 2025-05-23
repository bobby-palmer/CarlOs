// give boot hard a 4KB stack
export fn boot() linksection(".text.boot") callconv(.naked) noreturn {
    asm volatile (
        \\ la sp, __kernel_end
        \\ li t0, 4096
        \\ add sp, sp, t0
        \\ j boot2
    ); 
}

// finish boot setup for boot hart
export fn boot2(_: u64, _: [*] const u8) noreturn {
    while (true) {}
}
