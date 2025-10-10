/// fn for the boot hart to get tmp stack
export fn _start() linksection(".text.boot") callconv(.naked) noreturn {
    asm volatile (
        \\ la sp, __stack_top
        \\ j kmain
    );
}

const std = @import("std");
const sbi = @import("sbi.zig");

/// rest of setup for the boot hart
export fn kmain(_: u64, _: [*]const u8) noreturn {
    clearBss();
    stop();
}

/// Halt cpu
fn stop() noreturn {
    while (true) {
        asm volatile ("wfi");
    }
}

// TODO learn about this!
extern var __bss: u8;
extern var __bss_end: u8;

fn clearBss() void {
    const bss_start = @intFromPtr(&__bss);
    const bss_end = @intFromPtr(&__bss_end);
    const bss_len = bss_end - bss_start;

    const bss_slice = @as([*]u8, @ptrFromInt(bss_start))[0..bss_len];
    @memset(bss_slice, 0);
}

extern var __early_alloc_start: u8;
extern var __early_alloc_end: u8;

fn getHeapBuffer() []u8 {
    const start = @intFromPtr(&__early_alloc_start);
    const end = @intFromPtr(&__early_alloc_end);
    const len = end - start;
    return @as([*]u8, @ptrFromInt(start))[0..len];
}
