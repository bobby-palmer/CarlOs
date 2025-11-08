const std = @import("std");
const sbi = @import("sbi.zig");
const console = @import("console.zig");
const common = @import("common.zig");
const FdtParser = @import("FdtParser.zig");
const pmm = @import("pmm.zig");
const vmm = @import("vmm.zig");
const vma = @import("vma.zig");
const heap = @import("heap.zig");

var BOOT_HEAP: [common.constants.MB] u8 align(16) = undefined;

/// Boot strap initialization for one cpu
/// NOTE the order of some initializations are important!
export fn _kmain(_: usize, fdt: usize) noreturn {
    zeroBss(); // Must come first

    var fa = std.heap.FixedBufferAllocator.init(&BOOT_HEAP);
    const alloc = fa.allocator();

    const device_tree = FdtParser.parse(@ptrFromInt(fdt), alloc) catch {
        @panic("Fail to parse device tree");
    };

    if (!device_tree.header.isVerified()) {
        @panic("Device tree cannot be verified");
    }

    initPmm(&device_tree);

    vmm.init() catch {
        @panic("Fail to init vmm");
    };

    vma.init();

    var list = std.ArrayList(usize).initCapacity(heap.gpa, 100)
        catch unreachable;

    console.debug_writer.print("Init\n", .{}) 
        catch unreachable;

    for (0..10) |_| {
        while (list.items.len < 10000) {
            _ = list.addOne(heap.gpa) catch unreachable;
        }

        console.debug_writer.print("Init\n", .{}) 
            catch unreachable;

        list.deinit(heap.gpa);
    }

    _ = sbi.DebugConsole.consoleWrite("Hello from kmain\n") catch {};
    halt();
}

fn halt() noreturn {
    while (true) {
        asm volatile ("wfi");
    }
}

fn zeroBss() void {
    const start = @extern([*]u8, .{ .name = "_sbss"});
    const end = @extern([*]u8, .{ .name = "_ebss"});
    const slice = start[0.. end - start];
    @memset(slice, 0);
}

pub fn panic(
    message: []const u8, 
    _: ?*std.builtin.StackTrace, 
    pc: ?usize) noreturn {

    var writer = console.debug_writer;
    writer.print("\n!!!KERNEL PANIC!!!\n", .{}) catch {};
    writer.print("Error: {s}\n", .{message}) catch {};

    if (pc) |fault_addr| {
        writer.print("Fault Addr: {x}\n", .{fault_addr}) catch {};
    }
    
    halt(); 
}

/// Extract ram information and initialize phyical memory manager
fn initPmm(device_tree: *const FdtParser) void {

    var max_reserved = 
        @intFromPtr(
            @extern([*]u8, .{.name = "_kend"})) - common.constants.VMA_OFFSET;

    for (device_tree.mem_rsv_map.items) |span| {
        max_reserved = @max(
            max_reserved, 
            @as(usize, @intCast(span.start + span.len))
        );
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

            const base_addr = 
                std.mem.readVarInt(usize, reg[0..address_bytes], .big);

            const length = 
                std.mem.readVarInt(
                    usize, reg[address_bytes .. address_bytes + size_bytes], .big);

            const start = common.Paddr{ .paddr = max_reserved };
            const end = common.Paddr{ .paddr = base_addr + length };

            pmm.init(start, end);
            return;
        }
    }
}
