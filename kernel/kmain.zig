export fn _start() linksection(".text.boot") callconv(.naked) noreturn {
    asm volatile (
        \\ la sp, __stack_top
        \\ j kmain
    );
}

export fn kmain(_: u64) noreturn {
    clearBss();

    const sbi = @import("sbi.zig");
    _ = sbi.debug_print("Hello from kmain\n");

    while (true) {}
}

extern var __bss: u8;
extern var __bss_end: u8;

fn clearBss() void {
    
    const bss_start = @intFromPtr(&__bss);
    const bss_end = @intFromPtr(&__bss_end);
    const bss_len = bss_end - bss_start;
    
    const bss_slice = @as([*]u8, @ptrFromInt(bss_start))[0..bss_len];
    @memset(bss_slice, 0);
}
