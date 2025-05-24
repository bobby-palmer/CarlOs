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

    while (true) {}
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
    const tree_size = std.mem.bigToNative(u32, fdt_header.size_dt_struct) 
        / @sizeOf(u32);

    const tree = @as([*] const u32, @ptrCast(fdt_header)) +
        @sizeOf(FdtHeader) + std.mem.bigToNative(u32, fdt_header.off_dt_struct); 

    for (0..tree_size) |i| {
        if (std.mem.bigToNative(u32, tree[i]) == FDT_BEGIN_NODE and
            std.mem.eql(u8, "memory", fdtGetNodeName(@ptrCast(tree + i + 1)))) {

            print("found memory");
        }
    }
}

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

fn fdtGetNodeName(nameStart: [*] const u8) [] const u8 {
    var i: usize = 0;

    while (true) {
        if (nameStart[i] == '@' or nameStart[i] == 0) {
            return nameStart[0..i];
        }

        i += 1;
    }
}

// move later this is for debuging
fn putChar(ch: u8) void {
    asm volatile(
        "ecall"
        :
        : [ch]     "{a0}" (ch),
          [id]     "{a6}" (0),
          [legacy] "{a7}" (1),
        : "memory", "a0", "a1"
    );
}

fn print(str: [] const u8) void {
    for (str) |ch| {
        putChar(ch);
    }
}
