//! Setup the user to kernel entry for faults. TODO fix for riscv-64

const riscv = @import("riscv.zig");

/// Set entry pointer to call exception handler
pub fn init() void {
    const entry_ptr = @intFromPtr(&kernelEntry);
    riscv.writeCSR("stvec", @intCast(entry_ptr));
}

/// Kernel trap handler
export fn handleTrap(_: *TrapFrame) void {
    const scause = riscv.readCSR("scause");
    const stval = riscv.readCSR("stval");
    const user_pc = riscv.readCSR("sepc");

    _ = scause;
    _ = stval;
    _ = user_pc;

    // TODO implement syscalls and what not
    @panic("Trap handler is not implemented");
}


/// Exception entry point, saves all the registers
/// jumps to handle exception and then returns
/// after restoring the registers
fn kernelEntry() align(4) callconv(.naked) void {
    asm volatile (
        \\ csrw sscratch, sp
        \\ addi sp, sp, -8 * 31
        \\ sd ra,  8 * 0(sp)
        \\ sd gp,  8 * 1(sp)
        \\ sd tp,  8 * 2(sp)
        \\ sd t0,  8 * 3(sp)
        \\ sd t1,  8 * 4(sp)
        \\ sd t2,  8 * 5(sp)
        \\ sd t3,  8 * 6(sp)
        \\ sd t4,  8 * 7(sp)
        \\ sd t5,  8 * 8(sp)
        \\ sd t6,  8 * 9(sp)
        \\ sd a0,  8 * 10(sp)
        \\ sd a1,  8 * 11(sp)
        \\ sd a2,  8 * 12(sp)
        \\ sd a3,  8 * 13(sp)
        \\ sd a4,  8 * 14(sp)
        \\ sd a5,  8 * 15(sp)
        \\ sd a6,  8 * 16(sp)
        \\ sd a7,  8 * 17(sp)
        \\ sd s0,  8 * 18(sp)
        \\ sd s1,  8 * 19(sp)
        \\ sd s2,  8 * 20(sp)
        \\ sd s3,  8 * 21(sp)
        \\ sd s4,  8 * 22(sp)
        \\ sd s5,  8 * 23(sp)
        \\ sd s6,  8 * 24(sp)
        \\ sd s7,  8 * 25(sp)
        \\ sd s8,  8 * 26(sp)
        \\ sd s9,  8 * 27(sp)
        \\ sd s10, 8 * 28(sp)
        \\ sd s11, 8 * 29(sp)

        \\ csrr a0, sscratch
        \\ sd a0, 8 * 30(sp)

        \\ mv a0, sp
        \\ call handleTrap

        \\ ld ra,  8 * 0(sp)
        \\ ld gp,  8 * 1(sp)
        \\ ld tp,  8 * 2(sp)
        \\ ld t0,  8 * 3(sp)
        \\ ld t1,  8 * 4(sp)
        \\ ld t2,  8 * 5(sp)
        \\ ld t3,  8 * 6(sp)
        \\ ld t4,  8 * 7(sp)
        \\ ld t5,  8 * 8(sp)
        \\ ld t6,  8 * 9(sp)
        \\ ld a0,  8 * 10(sp)
        \\ ld a1,  8 * 11(sp)
        \\ ld a2,  8 * 12(sp)
        \\ ld a3,  8 * 13(sp)
        \\ ld a4,  8 * 14(sp)
        \\ ld a5,  8 * 15(sp)
        \\ ld a6,  8 * 16(sp)
        \\ ld a7,  8 * 17(sp)
        \\ ld s0,  8 * 18(sp)
        \\ ld s1,  8 * 19(sp)
        \\ ld s2,  8 * 20(sp)
        \\ ld s3,  8 * 21(sp)
        \\ ld s4,  8 * 22(sp)
        \\ ld s5,  8 * 23(sp)
        \\ ld s6,  8 * 24(sp)
        \\ ld s7,  8 * 25(sp)
        \\ ld s8,  8 * 26(sp)
        \\ ld s9,  8 * 27(sp)
        \\ ld s10, 8 * 28(sp)
        \\ ld s11, 8 * 29(sp)
        \\ ld sp, 8 * 30(sp)
        \\ sret
    );
}

const TrapFrame = extern struct {
    ra: u64,
    gp: u64,
    tp: u64,
    t0: u64,
    t1: u64,
    t2: u64,
    t3: u64,
    t4: u64,
    t5: u64,
    t6: u64,
    a0: u64,
    a1: u64,
    a2: u64,
    a3: u64,
    a4: u64,
    a5: u64,
    a6: u64,
    a7: u64,
    s0: u64,
    s1: u64,
    s2: u64,
    s3: u64,
    s4: u64,
    s5: u64,
    s6: u64,
    s7: u64,
    s8: u64,
    s9: u64,
    s10: u64,
    s11: u64,
    sp: u64,
};
