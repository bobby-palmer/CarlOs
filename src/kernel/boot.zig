// give boot hart a 4KB stack
export fn boot() linksection(".text.boot") callconv(.naked) noreturn {
    asm volatile (
        \\ la sp, __kernel_end
        \\ li t0, 4096
        \\ add sp, sp, t0
        \\ j boot2
    ); 
}

// finish boot setup for boot hart
export fn boot2(_: u64, dtb: [*] const u8) noreturn {
    zeroBss();
    initRam(dtb);

    // TODO: wake up other cpus here!

    boot3();
}

fn boot3() noreturn {
    const sbi = @import("sbi.zig");
    const trap = @import("trap.zig");

    sbi.writeCsr("stvec", @intFromPtr(&trap.trapEntry));

    while(true){}
}

fn zeroBss() void {
    const bss_start = @extern([*] u8, .{.name = "__bss_start"});
    const bss_end = @extern([*] u8, .{.name = "__bss_end"});

    const len = bss_end - bss_start;
    @memset(bss_start[0..len], 0);
}

const std = @import("std");

fn initRam(dtb: [*] const u8) void {
    const fdt_header = @as(* const FdtHeader, @ptrCast(@alignCast(dtb)));

    const tree = @as([*] const u32, @ptrCast(@alignCast(dtb 
        + std.mem.bigToNative(u32, fdt_header.off_dt_struct))));
    const tree_size = std.mem.bigToNative(u32, fdt_header.size_dt_struct) 
        / @sizeOf(u32);

    const strings = dtb + std.mem.bigToNative(u32, fdt_header.off_dt_strings);
    const strings_size = std.mem.bigToNative(u32, fdt_header.size_dt_strings);
    const reg_offset = fdtGetStringOff("reg", strings, strings_size);

    if (reg_offset == null) {
        return;
    }

    for (0..tree_size) |i| {

        if (std.mem.bigToNative(u32, tree[i]) == FDT_BEGIN_NODE and
            std.mem.eql(u8, "memory", fdtGetNodeName(@ptrCast(tree + i + 1)))) {

            var j = i;
            while (std.mem.bigToNative(u32, tree[j]) != FDT_END_NODE) {

                if (std.mem.bigToNative(u32, tree[j]) == FDT_PROP and
                    std.mem.bigToNative(u32, tree[j + 2]) == reg_offset.?) {
                    
                    const len = std.mem.bigToNative(u32, tree[j + 1]);
                    const prop = tree + j + 3;

                    for (0..len / @sizeOf(u64) / 2) |reg| {
                        var base: u64 = std.mem.bigToNative(u32, prop[reg * 4]);
                        base <<= @sizeOf(u32);
                        base |= std.mem.bigToNative(u32, prop[reg * 4 + 1]);

                        var extend: u64 = std.mem.bigToNative(u32, 
                            prop[reg * 4 + 2]);
                        extend <<= @sizeOf(u32);
                        extend |= std.mem.bigToNative(u32, prop[reg * 4 + 3]);

                        const kernel_end: u64 = @intFromPtr(@extern([*] u8, .{
                            .name = "__kernel_end"
                        })); 

                        if (base <= kernel_end and kernel_end < base + extend) {
                            const alloc = @import("page_allocator.zig");
                            alloc.addRam(kernel_end + 4096, base + extend);
                        }
                    }

                    
                }

                j += 1;
            }
        }
    }
}

// FDT spec, move this to its own parser later
const FDT_BEGIN_NODE = 0x00000001;
const FDT_END_NODE = 0x00000002;
const FDT_PROP = 0x00000003;
const FDT_NOP = 0x00000004;
const FDT_END = 0x00000009;

const FdtHeader = extern struct {
    magic: u32,
    totalsize: u32,
    off_dt_struct: u32,
    off_dt_strings: u32,
    off_mem_rsvmap: u32,
    version: u32,
    last_comp_version: u32,
    boot_cpuid_phys: u32,
    size_dt_strings: u32,
    size_dt_struct: u32,
};

fn fdtGetNodeName(name_start: [*] const u8) [] const u8 {
    var i: usize = 0;

    while (true) {
        if (name_start[i] == '@' or name_start[i] == 0) {
            return name_start[0..i];
        }

        i += 1;
    }
}

fn fdtGetStringOff(search: [] const u8, strings: [*] const u8, len: u32) ?u32 {
    var i: u32 = 0;

    while (i < len) {
        var j = i;

        while (strings[j] != 0)
            j += 1;

        if (std.mem.eql(u8, search, strings[i..j])) {
            return i;
        }

        i = j + 1;
    }

    return null;
}
