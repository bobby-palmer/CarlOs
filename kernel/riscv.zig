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

/// Flush and invalidate TLB
pub inline fn sfenceVma() void {
    asm volatile("sfence.vma zero, zero");
}
