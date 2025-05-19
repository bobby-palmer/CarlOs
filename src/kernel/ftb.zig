
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

pub const Dtb = [*] align(@alignOf(u32)) u8;

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

fn getPropOffset(dtb: Dtb, prop: []const u8) ?u32 {
    
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

pub fn getBootCpuId(dtb: Dtb) u32 {
    return getField(dtb, "boot_cpuid_phys");
}

pub fn getCpuCount(dtb: Dtb) u32 {
    const device_type_off = getPropOffset(dtb, "device_type");

    if (device_type_off == null) {
        return 0;
    }

    const structs_off = getField(dtb, "off_dt_struct") / @sizeOf(u32);
    const structs_count = getField(dtb, "size_dt_struct") / @sizeOf(u32);
    const structs = @as([*]u32, @ptrCast(dtb)) + structs_off;

    var count: u32 = 0;

    for (0..structs_count) |i| {

        if (std.mem.bigToNative(u32, structs[i]) == FDT_PROP) {
            const len = std.mem.bigToNative(u32, structs[i + 1]);
            const nameoff = std.mem.bigToNative(u32, structs[i + 2]);
            const valStart = @as([*]u8, @ptrCast(structs + i + 3));

            if (nameoff == device_type_off.? and 
                std.mem.eql(u8, valStart[0..len - 1], "cpu")) { 
                count += 1;
            }
        }
    }

    return count;
}
