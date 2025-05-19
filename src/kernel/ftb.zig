const DtbHeader = extern struct {
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

pub const Dtb = [*]align(@alignOf(DtbHeader)) u8;

pub fn getBootCpuId(dtb: Dtb) u32 {
    return (
        @as(*DtbHeader, @ptrCast(dtb)).*.boot_cpuid_phys
    );
}
