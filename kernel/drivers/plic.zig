//! Plic driver

const TrapFrame = @import("../trapframe.zig").TrapFrame;

pub const DeviceConfig = struct {
    /// The unique Interrupt ID assigned to this device by the hardware.
    interrupt_id: u32,
    /// The priority level the PLIC should be configured with for this source.
    /// (Must be non-zero to be forwarded; usually 1 for low-priority devices).
    initial_priority: u32,
    /// The function pointer to the device driver's specific interrupt handler.
    /// This is what the PLIC dispatcher calls.
    handler_fn: fn(*TrapFrame) void,
};

/// Boot initialization, should be called only by the boot hart
pub fn init(plic_base_addr: usize, devices: []const DeviceConfig) void { 
    PLIC_BASE_ADDR = plic_base_addr;
    DEVICES = devices;

    for (devices) |device| {
        const addr = getPriorityAddr(device.interrupt_id);
        mmio_write(addr, device.initial_priority);
    }
}

/// Per hart initialization, should be called by each hart when booting
pub fn initHart() void { 
    unreachable;
}

/// Handler call back function exceptions
pub fn handle(frame: *TrapFrame) void { 
    _ = frame;
    unreachable;
}

fn getPriorityAddr(source_id: u32) u64 {
    // Priority Registers start at 0x4. Source 0 is unused.
    return PLIC_BASE_ADDR + 0x4 + source_id * 4;
}

fn getEnableAddr(hart_id: u64) u64 {
    // Each S-mode context gets a block of enable registers. 
    // Hart 0 S-mode starts at 0x2000, Hart 1 S-mode starts at 0x2080, etc.
    const S_CONTEXT_OFFSET: u64 = 0x80;
    return PLIC_BASE_ADDR + 0x2000 + (hart_id * S_CONTEXT_OFFSET);
}

fn getClaimCompleteAddr(hart_id: u64) u64 {
    // Claim/Complete registers are spaced every 0x1000 bytes per context block.
    // Hart 0 S-mode register is at 0x201004.
    const S_CONTEXT_OFFSET: u64 = 0x1000;
    return PLIC_BASE_ADDR + 0x2004 + (hart_id * S_CONTEXT_OFFSET);
}

fn getThresholdAddr(hart_id: u64) u64 {
    // Threshold register is right before the Claim/Complete register.
    const S_CONTEXT_OFFSET: u64 = 0x1000;
    return PLIC_BASE_ADDR + 0x2000 + (hart_id * S_CONTEXT_OFFSET);
}

fn mmio_read(addr: u64) u32 { 
    return @as(*volatile u32, @ptrFromInt(addr)).*;
}

fn mmio_write(addr: u64, val: u32) void {
    @as(*volatile u32, @ptrFromInt(addr)).* = val;
}

var PLIC_BASE_ADDR: usize = undefined;
var DEVICES: []const DeviceConfig = undefined;
