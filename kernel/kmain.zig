/// 64 KB
const BOOT_STACK_SIZE: usize = 64 * (1 << 10);
/// temp stack for booting
var BOOT_STACK: [BOOT_STACK_SIZE]u8 align(16) = undefined;

/// Setup boot stack for boot hart and jump to boot
export fn _start() linksection(".text.boot") callconv(.naked) noreturn {
    asm volatile (
        \\ mv sp, %[stack_start]
        \\ li t0, %[stack_size]
        \\ add t0, sp, sp
        \\ j boot
        :
        : [stack_start] "r" (&BOOT_STACK),
          [stack_size] "i" (BOOT_STACK_SIZE)
    );
}

/// 1MB
const EARLY_HEAP_SIZE: usize = 1 << 20;
/// Early heap for boot sequence
var EARLY_HEAP: [EARLY_HEAP_SIZE]u8 align(16) = undefined;

const std = @import("std");
const sbi = @import("sbi.zig");
const Fdt = @import("fdt.zig");
const pmm = @import("pmm.zig");
const exception = @import("exception.zig");

/// rest of setup for the boot hart
export fn boot(_: u64, fdt: [*]const u64) noreturn {
    clearBss(); // Must do this first, do not move this

    exception.init(); // setup jump vector

    var fa = std.heap.FixedBufferAllocator.init(&EARLY_HEAP);
    const early_allocator = fa.allocator();

    const device_tree: Fdt = Fdt.parse(fdt, early_allocator) catch |err| {
        @panic(@errorName(err));
    };

    if (!device_tree.header.isVerified()) {
        @panic("Bad fdt header!");
    }

    initPmm(device_tree, early_allocator) catch |err| {
        @panic(@errorName(err));
    };

    halt();
}

/// Simple global panic handler to print out a message
// TODO add backtrace
pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = sbi.DebugConsole.consoleWrite(message) catch {};
    _ = sbi.DebugConsole.consoleWrite("\n") catch {};
    halt(); 
}

/// Halt cpu
fn halt() noreturn {
    while (true) {
        asm volatile ("wfi");
    }
}

extern var __bss: u8;
extern var __bss_end: u8;

fn clearBss() void {
    const bss_start = @intFromPtr(&__bss);
    const bss_end = @intFromPtr(&__bss_end);
    const bss_len = bss_end - bss_start;

    const bss_slice = @as([*]u8, @ptrFromInt(bss_start))[0..bss_len];
    @memset(bss_slice, 0);
}

extern var __kstart: u8;
extern var __kend: u8;

/// Extract ram information and initialize phyical memory manager
fn initPmm(device_tree: Fdt, alloc: std.mem.Allocator) !void {

    var reserved = try std.ArrayList(pmm.MemoryRegion).initCapacity(alloc, 3);

    for (device_tree.mem_rsv_map.items) |block| {
        try reserved.append(alloc, .{
            .start = block.address,
            .end = block.address + block.size,
        });
    }

    try reserved.append(alloc, .{
        .start = @intFromPtr(&__kstart),
        .end = @intFromPtr(&__kend),
    });

    const address_bytes = @sizeOf(u32) *
        if (device_tree.root.getProp("#address-cells")) 
            |prop| std.mem.readInt(u32, prop[0..4], .big)
        else 2;

    const size_bytes = @sizeOf(u32) *
        if (device_tree.root.getProp("#size-cells")) 
            |prop| std.mem.readInt(u32, prop[0..4], .big)
        else 1;

    for (device_tree.root.sub_nodes.items) |node| {
        if (std.mem.eql(u8, node.getUnitName(), "memory")) {
            const reg = node.getProp("reg") orelse unreachable;
            var i: usize = 0;

            while (i < reg.len) {
                const base_addr = std.mem.readVarInt(u64, reg[i..i +
                    address_bytes], .big);
                i += address_bytes;
                const length = std.mem.readVarInt(u64, reg[i .. i +
                    size_bytes], .big);
                i += size_bytes;

                const region = pmm.MemoryRegion {
                    .start = base_addr,
                    .end = base_addr + length,
                };

                pmm.addRam(region, reserved.items);
            }
        }
    }
}
