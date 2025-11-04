//! Exception handler entry point (syscalls / interupt handlers)

const common = @import("common.zig");
const TrapFrame = @import("trapframe.zig").TrapFrame;

/// Turn on exception handler for this CPU
pub fn init() void {
    common.writeCSR("stvec", @intFromPtr(&_trap_entry));
}

/// Exception handler
export fn handleTrap(frame: *TrapFrame) void {
    _ = frame;

    const scause = common.readCSR("scause");

    switch (scause) {
        // Synchronous Exceptions
        0 => @panic("Missaligned address"),
        2 => @panic("Illegal instruction"),
        3 => @panic("Breakpoint hit"),
        8 => @panic("ECALL from U-Mode"),
        9 => @panic("ECALL from S-mode"),
        12 => @panic("Instruction page fault"),
        13 => @panic("Load page fault"),
        15 => @panic("Store/AMO Page Fault"),

        // Async Exception
        (1 << 63) | 1 => @panic("Supervisor Software Interrupt (SSIP)"),
        (1 << 63) | 5 => @panic("Supervisor Timer Interrupt (STIP)"),
        (1 << 63) | 9 => @panic("Supervisor External Interrupt (SEIP)"),

        // Unknown Exception
        else => @panic("Unhandled exception scause"),
    }
}

/// Entry point to save CPU context and jump to handler
export fn _trap_entry() align(4) callconv(.naked) void {
    asm volatile (
        // 1. Save stack pointer at exception point
        \\ csrw sscratch, sp

        // 2. Allocate space for TrapFrame
        \\ addi sp, sp, -8 * 31

        // 3. Save all GPRs except for sp
        \\ sd ra, 8 * 0(sp)
        \\ sd gp, 8 * 2(sp)
        \\ sd tp, 8 * 3(sp)

        \\ sd t0, 8 * 4(sp)
        \\ sd t1, 8 * 5(sp)
        \\ sd t2, 8 * 6(sp)
        \\ sd t3, 8 * 7(sp)
        \\ sd t4, 8 * 8(sp)
        \\ sd t5, 8 * 9(sp)
        \\ sd t6, 8 * 10(sp)

        \\ sd s0, 8 * 11(sp)
        \\ sd s1, 8 * 12(sp)
        \\ sd s2, 8 * 13(sp)
        \\ sd s3, 8 * 14(sp)
        \\ sd s4, 8 * 15(sp)
        \\ sd s5, 8 * 16(sp)
        \\ sd s6, 8 * 17(sp)
        \\ sd s7, 8 * 18(sp)
        \\ sd s8, 8 * 19(sp)
        \\ sd s9, 8 * 20(sp)
        \\ sd s10, 8 * 21(sp)
        \\ sd s11, 8 * 22(sp)

        \\ sd a0, 8 * 23(sp)
        \\ sd a1, 8 * 24(sp)
        \\ sd a2, 8 * 25(sp)
        \\ sd a3, 8 * 26(sp)
        \\ sd a4, 8 * 27(sp)
        \\ sd a5, 8 * 28(sp)
        \\ sd a6, 8 * 29(sp)
        \\ sd a7, 8 * 30(sp)

        // 4. Save sp @ exception point
        \\ csrr a0, sscratch
        \\ sd a0, 8 * 1(sp)

        // 5. call trap handler
        \\ mv a0, sp
        \\ call handleTrap

        // 6. Restore all except for sp
        \\ ld ra, 8 * 0(sp)
        \\ ld gp, 8 * 2(sp)
        \\ ld tp, 8 * 3(sp)

        \\ ld t0, 8 * 4(sp)
        \\ ld t1, 8 * 5(sp)
        \\ ld t2, 8 * 6(sp)
        \\ ld t3, 8 * 7(sp)
        \\ ld t4, 8 * 8(sp)
        \\ ld t5, 8 * 9(sp)
        \\ ld t6, 8 * 10(sp)

        \\ ld s0, 8 * 11(sp)
        \\ ld s1, 8 * 12(sp)
        \\ ld s2, 8 * 13(sp)
        \\ ld s3, 8 * 14(sp)
        \\ ld s4, 8 * 15(sp)
        \\ ld s5, 8 * 16(sp)
        \\ ld s6, 8 * 17(sp)
        \\ ld s7, 8 * 18(sp)
        \\ ld s8, 8 * 19(sp)
        \\ ld s9, 8 * 20(sp)
        \\ ld s10, 8 * 21(sp)
        \\ ld s11, 8 * 22(sp)

        \\ ld a0, 8 * 23(sp)
        \\ ld a1, 8 * 24(sp)
        \\ ld a2, 8 * 25(sp)
        \\ ld a3, 8 * 26(sp)
        \\ ld a4, 8 * 27(sp)
        \\ ld a5, 8 * 28(sp)
        \\ ld a6, 8 * 29(sp)
        \\ ld a7, 8 * 30(sp)

        // 7. Restore sp and return
        \\ ld sp, 8 * 1(sp)
        \\ sret
    );
}
