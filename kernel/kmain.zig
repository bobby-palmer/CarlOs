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
        \\ j boot2
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
export fn boot2(_: u64, fdt: [*]const u64) noreturn {
    clearBss(); // Must do this first, do not move this

    var fa = std.heap.FixedBufferAllocator.init(&EARLY_HEAP);
    const early_allocator = fa.allocator();

    const device_tree: Fdt = Fdt.parse(fdt, early_allocator) catch |err| {
        @panic(@errorName(err));
    };

    if (!device_tree.header.isVerified()) {
        @panic("Bad fdt header!");
    }

    for (device_tree.root.sub_nodes.items) |node| {
        if (std.mem.eql(u8, node.getUnitName(), "memory")) {
            _ = sbi.debugPrint("Found memory node\n");
        }
    }

    halt();
}

/// Simple global panic handler to print out a message
pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = sbi.debugPrint("\n\nKERNEL PANIC: ");
    _ = sbi.debugPrint(message);
    _ = sbi.debugPrint("\n");
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

