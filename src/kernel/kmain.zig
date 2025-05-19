extern const __kernel_end: u8;

export fn boot() callconv(.Naked) void {
    asm volatile (
        \\ la sp, __kernel_end
        \\ j kmain
        :
        :
        :
    );
}

export fn kmain(hart_id: u64) void {

    if (hart_id == 0) {

    }

    while (true) {}
}
