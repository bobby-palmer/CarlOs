/// Kernel trap handler
export fn handleTrap(_: *TrapFrame) void {
    const scause = readCSR("scause");
    const stval = readCSR("stval");
    const user_pc = readCSR("sepc");

    _ = scause;
    _ = stval;
    _ = user_pc;

    // TODO implement syscalls and what not
    @panic("Trap handler is not implemented");
}

/// Set entry pointer to call exception handler
pub fn init() void {
    const entry_ptr = @intFromPtr(&kernelEntry);
    writeCSR("stvec", @intCast(entry_ptr));
}

// Read a CSR register
inline fn readCSR(comptime reg: []const u8) u64 {
    var result: u64 = undefined;
    asm volatile ("csrr %[ret], " ++ reg
        : [ret] "=r" (result),
    );
    return result;
}

// Write to a CSR register
inline fn writeCSR(comptime reg: []const u8, value: u64) void {
    asm volatile ("csrw " ++ reg ++ ", %[val]"
        :
        : [val] "r" (value),
    );
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
    ra: u32,
    gp: u32,
    tp: u32,
    t0: u32,
    t1: u32,
    t2: u32,
    t3: u32,
    t4: u32,
    t5: u32,
    t6: u32,
    a0: u32,
    a1: u32,
    a2: u32,
    a3: u32,
    a4: u32,
    a5: u32,
    a6: u32,
    a7: u32,
    s0: u32,
    s1: u32,
    s2: u32,
    s3: u32,
    s4: u32,
    s5: u32,
    s6: u32,
    s7: u32,
    s8: u32,
    s9: u32,
    s10: u32,
    s11: u32,
    sp: u32,
};
