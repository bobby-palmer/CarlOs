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
const Sbi = @import("sbi.zig");
const Fdt = @import("fdt.zig");
const Pmm = @import("pmm.zig");
const Io = @import("io.zig");
const Exception = @import("exception.zig");

/// rest of setup for the boot hart
export fn boot(_: u64, fdt: [*]const u64) noreturn {
    clearBss(); // Must do this first, do not move this

    Exception.init(); // setup jump vector

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
    _ = Sbi.DebugConsole.consoleWrite(message) catch {};
    _ = Sbi.DebugConsole.consoleWrite("\n") catch {};
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
    const address_bytes = @sizeOf(u32) *
        if (device_tree.root.getProp("#address-cells")) 
            |prop| std.mem.readInt(u32, prop[0..4], .big)
        else 2;

    const size_bytes = @sizeOf(u32) *
        if (device_tree.root.getProp("#size-cells")) 
            |prop| std.mem.readInt(u32, prop[0..4], .big)
        else 1;

    var ram = try std.ArrayList(Pmm.MemoryRegion).initCapacity(alloc, 3);

    for (device_tree.root.sub_nodes.items) |node| {
        if (std.mem.eql(u8, node.getUnitName(), "memory")) {
            const reg = node.getProp("reg") orelse unreachable;
            var i: usize = 0;

            while (i < reg.len) {
                const base_addr = std.mem.readVarInt(u64, reg[i..i + address_bytes], .big);
                i += address_bytes;
                const length = std.mem.readVarInt(u64, reg[i .. i + size_bytes], .big);
                i += size_bytes;

                try ram.append(alloc, .{
                    .base_addr = base_addr,
                    .length = length
                });
            }
        }
    }

    var reserved = try std.ArrayList(Pmm.MemoryRegion).initCapacity(alloc, 3);

    for (device_tree.mem_rsv_map.items) |block| {
        try reserved.append(alloc, .{
            .base_addr = block.address,
            .length = block.size,
        });
    }

    try reserved.append(alloc, .{
        .base_addr = @intFromPtr(&__kstart),
        .length = @intFromPtr(&__kend) - @intFromPtr(&__kstart)
    });

    Pmm.init(ram.items, reserved.items);
}
