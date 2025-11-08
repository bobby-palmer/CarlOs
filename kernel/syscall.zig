const common = @import("common.zig");
const riscv = common.riscv;

pub fn handleSyscall(trap_frame: *riscv.TrapFrame) void {
    switch (trap_frame.a7) {

        .exit => {},
        .fork => {},
        .execve => {},
        .waitpid => {},
        .getpid => {},

        .read => {},
        .write => {},
        .open => {},
        .close => {},

        _ => {},
    }
}

const Syscall = enum(u64) {
    // Process management
    exit = 1,
    fork,
    execve,
    waitpid,
    getpid,
    
    // I/O and File Operations
    read,
    write,
    open,
    close,

    // Add more calls here
    
    // --- Error Case ---
    _,
};
