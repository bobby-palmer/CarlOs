// Set stack pointer = (hart_id + 1) * 4096 + __kernel_end
// call kmain
// loop forever
export fn boot() linksection(".text.boot") callconv(.naked) noreturn {
    asm volatile(
        \\ la   t0, __kernel_end
        \\ addi t1, a0, 1
        \\ slli t1, t1, 12
        \\ add  sp, t0, t1
        \\ call kmain
        \\ 1:
        \\ wfi
        \\ j 1b
    );
}

const ftb = @import("ftb.zig");
const sbi = @import("sbi.zig");

export fn kmain(hart_id: u32, dtb: ftb.Dtb) void {

    if (hart_id == ftb.getBootCpuId(dtb)) {
        zeroBss();
        sbi.putChar('Y');
    }
}

fn zeroBss() void {
    const bss_start = @extern([*]u8, .{.name = "__bss_start"});
    const bss_end   = @extern([*]u8, .{.name = "__bss_end"});
    const bss_len = @intFromPtr(bss_end) - @intFromPtr(bss_start);
    @memset(bss_start[0..bss_len], 0);
}
