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

fn initRam(dtb: [*] const u8) void {
    _ = @as(* const Fdt, @ptrCast(@alignCast(dtb)));
}

const FDT_BEGIN_NODE = 0x00000001;
const FDT_END_NODE = 0x00000002;
const FDT_PROP = 0x00000003;
const FDT_NOP = 0x00000004;
const FDT_END = 0x00000009;

const Fdt = extern struct {
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

