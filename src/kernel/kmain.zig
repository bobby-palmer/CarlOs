
// Set stack pointer = (hard_id + 1) * 4096 + __kernel_end
// call kmain
// loop forever
export fn boot() linksection(".text.boot") callconv(.naked) noreturn {
    asm volatile(
        \\ la   t0, __kernel_end
        \\ addi t1, a0, 1
        \\ slli t1, t1, 12
        \\ add  sp, t0, t1
        \\ call kmain
        \\ 1: j 1b
    );
}

export fn kmain(hart_id: u64) void {

    if (hart_id == 0) {
        zero_bss();
    }
}

fn zero_bss() void {
    const bss_start = @extern([*]u8, .{.name = "__bss_start"});
    const bss_end   = @extern([*]u8, .{.name = "__bss_end"});
    const bss_len = @intFromPtr(bss_end) - @intFromPtr(bss_start);
    @memset(bss_start[0..bss_len], 0);
}
