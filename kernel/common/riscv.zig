//! Small riscv assembly wrappers / state

/// Read a CSR register
pub inline fn readCSR(comptime reg: []const u8) u64 {
    var result: u64 = undefined;
    asm volatile ("csrr %[ret], " ++ reg
        : [ret] "=r" (result),
    );
    return result;
}

/// Write to a CSR register
pub inline fn writeCSR(comptime reg: []const u8, value: u64) void {
    asm volatile ("csrw " ++ reg ++ ", %[val]"
        :
        : [val] "r" (value),
    );
}

/// Force TLB flush, all address spaces, all pages
pub inline fn fenceVma() void {
    asm volatile ("sfence.vma zero, zero");
}

/// Get hart id of current cpu
pub inline fn getHartId() u64 {
    return readCSR("mhartid");
}

/// Saved context of CPU at an exception point. DO NOT CHANGE THIS!!!
pub const TrapFrame = extern struct {
    // Non-caller saved
    /// Return Address
    ra: u64,
    /// Stack Pointer (the stack pointer *before* the trap)
    sp: u64,
    /// Global Pointer
    gp: u64,
    /// Thread Pointer
    tp: u64,

    // Temporaries, Caller-saved
    t0: u64,
    t1: u64,
    t2: u64,
    t3: u64,
    t4: u64,
    t5: u64,
    t6: u64,

    // Saved Registers, Callee-saved
    /// Frame Pointer
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

    // Function Arguments, Caller-saved
    a0: u64,
    a1: u64,
    a2: u64,
    a3: u64,
    a4: u64,
    a5: u64,
    a6: u64,
    a7: u64,
};
