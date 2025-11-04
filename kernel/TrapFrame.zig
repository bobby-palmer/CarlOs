//! Saved state of cpu at an exception point

// ================ CSRs ================
/// Supervisor Exception Program Counter (PC of instruction that trapped)
sepc: u64,
/// Supervisor Cause Register (Reason for the trap: code and interrupt bit)
scause: u64,
/// Supervisor Status Register (Contains the privilege level and global interrupt enables)
sstatus: u64,

// ===== General Purpose Registers (GPRs) x1 - x31 ===========
// x1 - x4 (Non-caller saved)
/// x1: Return Address
ra: u64,
/// x2: Stack Pointer (the stack pointer *before* the trap)
sp: u64,
/// x3: Global Pointer
gp: u64,
/// x4: Thread Pointer
tp: u64,

// x5 - x7 (Temporaries, Caller-saved)
t0: u64,
t1: u64,
t2: u64,

// x8 - x9 (Saved Registers, Callee-saved)
/// x8: Frame Pointer / Saved Register 0
s0: u64,
/// x9: Saved Register 1
s1: u64,

// x10 - x17 (Function Arguments, Caller-saved)
a0: u64,
a1: u64,
a2: u64,
a3: u64,
a4: u64,
a5: u64,
a6: u64,
a7: u64,

// x18 - x27 (Saved Registers, Callee-saved)
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

// x28 - x31 (Temporaries, Caller-saved)
t3: u64,
t4: u64,
t5: u64,
t6: u64,
