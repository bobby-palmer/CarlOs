/// Setup boot stack for boot hart and jump to boot
export fn _start() linksection(".text.boot") callconv(.naked) noreturn {
    asm volatile (
        \\ la sp, __stack_top
        \\ j boot
    );
}

const std = @import("std");
const sbi = @import("sbi.zig");
const common = @import("common.zig");
const FdtParser = @import("FdtParser.zig");
const console = @import("console.zig");

const constants = common.constants;

var BOOT_HEAP: [constants.MB] u8 align(16) = undefined;

/// rest of setup for the boot hart
export fn boot(_: u64, fdt: [*]const u64) noreturn {
    zeroBss(); // Do not move this, code expects defaults to be zeroed

    var fa = std.heap.FixedBufferAllocator.init(&BOOT_HEAP);
    const alloc = fa.allocator();

    const parser = FdtParser.parse(fdt, alloc) catch {
        @panic("Fail to parse flattened device tree");
    };

    if (!parser.header.isVerified()) {
        @panic("Fail to verify device tree header");
    }

    parser.write(&console.debug_writer) catch {};

    _ = sbi.DebugConsole.consoleWrite("Kmain boot") catch {};

    halt();
}

/// Set global panic handler.
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

fn zeroBss() void {
    const start = @extern([*]u8, .{ .name = "__bss"});
    const end = @extern([*]u8, .{ .name = "__bss_end"});
    const slice = start[0.. end - start];
    @memset(slice, 0);
}

// Extract ram information and initialize phyical memory manager
// fn initPmm(device_tree: *const FdtParser, alloc: std.mem.Allocator) !void {
//
//     const __kstart = @extern([*]u8, .{ .name = "__kstart" });
//     const __kend = @extern([*]u8, .{ .name = "__kend" });
//
//     var reserved = try device_tree.mem_rsv_map.clone(alloc);
//     defer reserved.deinit(alloc);
//
//     try reserved.append(alloc, .{
//         .start = @intFromPtr(__kstart),
//         .len = @intFromPtr(__kend) - @intFromPtr(__kstart),
//     });
//
//     const address_bytes = @sizeOf(u32) *
//         if (device_tree.root.getProp("#address-cells")) 
//             |prop| std.mem.readInt(u32, prop[0..4], .big)
//         else 2;
//
//     const size_bytes = @sizeOf(u32) *
//         if (device_tree.root.getProp("#size-cells")) 
//             |prop| std.mem.readInt(u32, prop[0..4], .big)
//         else 1;
//
//     for (device_tree.root.sub_nodes.items) |node| {
//         if (std.mem.eql(u8, node.getUnitName(), "memory")) {
//             const reg = node.getProp("reg") orelse unreachable;
//             var i: usize = 0;
//
//             while (i < reg.len) {
//                 const base_addr = std.mem.readVarInt(u64, reg[i..i +
//                     address_bytes], .big);
//                 i += address_bytes;
//                 const length = std.mem.readVarInt(u64, reg[i .. i +
//                     size_bytes], .big);
//                 i += size_bytes;
//
//                 pmm.addRam(.{ .start = base_addr, .len = length }, reserved.items);
//             }
//         }
//     }
// }
