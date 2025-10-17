/// 64 KB
const BOOT_STACK_SIZE: usize = 64 * (1 << 10);
/// temp stack for booting
var BOOT_STACK: [BOOT_STACK_SIZE]u8 align(16) = undefined;

/// Setup boot stack for boot hart and jump to boot2
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

/// rest of setup for the boot hart
export fn boot(_: u64, fdt: [*]const u64) noreturn {
    clearBss(); // Must do this first, do not move this

    var fa = std.heap.FixedBufferAllocator.init(&EARLY_HEAP);
    const early_allocator = fa.allocator();

    const device_tree: Fdt = Fdt.parse(fdt, early_allocator) catch |err| {
        @panic(@errorName(err));
    };

    if (!device_tree.header.isVerified()) {
        @panic("Bad fdt header!");
    }

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
                _ = std.mem.readVarInt(u64, reg[i..i + address_bytes], .big);
                i += address_bytes;
                _ = std.mem.readVarInt(u64, reg[i .. i + size_bytes], .big);
                i += size_bytes;
            }
        }
    }

    _ = sbi.DebugConsole.consoleWrite("GOOD!\n") catch unreachable;
    _ = sbi.DebugConsole.consoleWrite("GOOD!\n") catch unreachable;

    halt();
}

/// Simple global panic handler to print out a message
pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    // _ = sbi.debugPrint("\n\n");
    // _ = sbi.debugPrint("\x1b[31m"); // Set color to red
    //
    // _ = sbi.debugPrint("===================================\n");
    // _ = sbi.debugPrint("|           KERNEL PANIC:         |\n");
    // _ = sbi.debugPrint("===================================\n");
    //
    // _ = sbi.debugPrint("\x1b[0m"); // reset color
    // _ = sbi.debugPrint("\n");
    //
    // _ = sbi.debugPrint("Error: ");
    // _ = sbi.debugPrint(message);
    // _ = sbi.debugPrint("\n");

    _ = sbi.DebugConsole.consoleWrite(message) catch {};
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

