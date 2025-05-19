const FDT_BEGIN_NODE = 0x00000001;
const FDT_END_NODE = 0x00000002;
const FDT_PROP = 0x00000003;
const FDT_NOP = 0x00000004;
const FDT_END = 0x00000009;

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

const std = @import("std");

// get value of field in native endian
fn getField(dtb: Dtb, comptime field: []const u8) u32 {
    if (!@hasField(DtbHeader, field)) {
        @compileError("DtbHeader has no field named: " ++ field);
    }

    return (
        std.mem.bigToNative(u32,
            @field(
                @as(*DtbHeader, @ptrCast(dtb)).*, 
                field
            )
        )
    );
}

pub fn getBootCpuId(dtb: Dtb) u32 {
    return getField(dtb, "boot_cpuid_phys");
}

pub fn getPropOffset(dtb: Dtb, prop: []const u8) ?u32 {
    
    const strings_off = getField(dtb, "off_dt_strings");
    const strings_size = getField(dtb, "size_dt_strings");

    var i: u32 = 0;

    while (i < strings_size) {
        const slice = std.mem.span(
            @as([*:0]u8, @ptrCast(dtb + strings_off + i))
        );

        if (std.mem.eql(u8, slice, prop)) {
            return i;
        } else {
            i += @intCast(slice.len + 1);
        }
    }

    return null;
}
