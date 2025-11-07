//! API implemented based on https://lists.riscv.org/g/tech-brs/attachment/361/0/riscv-sbi.pdf

const SbiError = error {
    SBI_ERR_FAILED,
    SBI_ERR_NOT_SUPPORTED,
    SBI_ERR_INVALID_PARAM,
    SBI_ERR_DENIED,
    SBI_ERR_INVALID_ADDRESS,
    SBI_ERR_ALREADY_AVAILABLE,
    SBI_ERR_ALREADY_STARTED,
    SBI_ERR_ALREADY_STOPPED,
    SBI_ERR_NO_SHMEM,
    SBI_ERR_INVALID_STATE,
    SBI_ERR_BAD_RANGE,
    SBI_ERR_TIMEOUT,
    SBI_ERR_IO,
};

const SbiArgs = struct {
    a0: usize = 0,
    a1: usize = 0,
    a2: usize = 0,
    a3: usize = 0,
    a4: usize = 0,
    a5: usize = 0,
};

/// Make OpenSBI Ecall
fn call(eid: i32, fid: i32, args: SbiArgs) SbiError!isize {
    var err: isize = undefined;
    var val: isize = undefined;

    asm volatile (
        \\mv a0, %[a0]
        \\mv a1, %[a1]
        \\mv a2, %[a2]
        \\mv a3, %[a3]
        \\mv a4, %[a4]
        \\mv a5, %[a5]
        \\mv a6, %[fid]
        \\mv a7, %[eid]
        \\ecall
        \\mv %[err], a0
        \\mv %[val], a1
        : [err] "=r" (err),
          [val] "=r" (val)
        : [eid] "r" (eid),
          [fid] "r" (fid),
          [a0] "r" (args.a0),
          [a1] "r" (args.a1),
          [a2] "r" (args.a2),
          [a3] "r" (args.a3),
          [a4] "r" (args.a4),
          [a5] "r" (args.a5)
        : .{ 
            .x10 = true,
            .x11 = true,
            .x12 = true,
            .x13 = true,
            .x14 = true,
            .x15 = true,
            .x16 = true,
            .x17 = true,
            .memory = true,
          }
    );

    return switch (err) {
        0 => val,
        -1 => SbiError.SBI_ERR_FAILED,
        -2 => SbiError.SBI_ERR_NOT_SUPPORTED,
        -3 => SbiError.SBI_ERR_INVALID_PARAM,
        -4 => SbiError.SBI_ERR_DENIED,
        -5 => SbiError.SBI_ERR_INVALID_ADDRESS,
        -6 => SbiError.SBI_ERR_ALREADY_AVAILABLE,
        -7 => SbiError.SBI_ERR_ALREADY_STARTED,
        -8 => SbiError.SBI_ERR_ALREADY_STOPPED,
        -9 => SbiError.SBI_ERR_NO_SHMEM,
        -10 => SbiError.SBI_ERR_INVALID_STATE,
        -11 => SbiError.SBI_ERR_BAD_RANGE,
        -12 => SbiError.SBI_ERR_TIMEOUT,
        -13 => SbiError.SBI_ERR_IO,
        else => unreachable,
    };
}

pub const Base = struct {
    pub const EID: i32 = 0x10;

    /// Returns true if the given SBI extension ID (EID) is available
    pub fn probeExtension(eid: i32) bool {
        const res = call(EID, 0x3, .{ 
            .a0 = @intCast(eid) 
        }) catch unreachable;

        return res != 0;
    }
};

pub const Timer = struct {
    pub const EID: i32 = 0x54494D45;

    /// Programs the clock for next event after stime_value time. stime_value
    /// is in absolute time. 
    pub fn setTimer(stime_value: u64) void {
        _ = call(EID, 0x0, .{
            .a0 = @intCast(stime_value)
        }) catch unreachable;
    }
};

pub const DebugConsole = struct {
    pub const EID: i32 = 0x4442434E;

    /// Write bytes to the debug console from input memory. This is a
    /// non-blocking SBI call and it may do partial/no writes if the debug
    /// console is not able to accept more bytes. If successful returns the
    /// number of bytes written
    pub fn consoleWrite(message: []const u8) SbiError!usize {
        const common = @import("common.zig");
        const paddr = common.Paddr.fromVaddr(@intFromPtr(message.ptr));

        return @intCast(try call(EID, 0x0, .{
            .a0 = message.len,
            .a1 = paddr.paddr,
            .a2 = 0, // whole address fits in the first argument
        }));
    }

    /// Read bytes from the debug console into an output memory. This is a
    /// non-blocking SBI call and it will not write anything into the output
    /// memory if there are no bytes to be read in the debug console.
    pub fn consoleRead(buffer: []u8) SbiError!usize {
        return @intCast(try call(EID, 0x1, .{
            .a0 = buffer.len,
            .a1 = @intFromPtr(buffer.ptr),
            .a2 = 0, // Ditto
        }));
    }

    /// Write a single byte to the debug console. This is a blocking SBI call
    /// and it will only return after writing the specified byte to the debug
    /// console. It will also return, with SBI_ERR_FAILED, if there are I/O
    /// errors
    pub fn consoleWriteByte(byte: u8) SbiError!void {
        _ = try call(EID, 0x2, .{
            .a0 = byte
        });
    }
};
