/// fn for the boot hart to get tmp stack
/// TODO change this to use static array in zig code instead of linker
export fn _start() linksection(".text.boot") callconv(.naked) noreturn {
    asm volatile (
        \\ la sp, __stack_top
        \\ j kmain
    );
}

const std = @import("std");
const sbi = @import("sbi.zig");
const fdt = @import("fdt.zig");

/// rest of setup for the boot hart
export fn kmain(_: u64, _: [*]const u64) noreturn {
    clearBss(); // Must do this first!!!

    _ = sbi.debugPrint("GOOD!");

    stop();
}

/// Halt cpu
fn stop() noreturn {
    while (true) {
        asm volatile ("wfi");
    }
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

