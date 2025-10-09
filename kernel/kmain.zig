/// fn for the boot hart to get tmp stack
export fn _start() linksection(".text.boot") callconv(.naked) noreturn {
    asm volatile (
        \\ la sp, __stack_top
        \\ j kmain
    );
}

/// rest of setup for the boot hart
export fn kmain(_: u64, dtb_bytes: [*]const u8) noreturn {
    clearBss();
    while (true) {}
}

// TODO make these scoped to the fn below
extern var __bss: u8;
extern var __bss_end: u8;

fn clearBss() void {
    
    const bss_start = @intFromPtr(&__bss);
    const bss_end = @intFromPtr(&__bss_end);
    const bss_len = bss_end - bss_start;
    
    const bss_slice = @as([*]u8, @ptrFromInt(bss_start))[0..bss_len];
    @memset(bss_slice, 0);
}
