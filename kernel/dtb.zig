const std = @import("std");

const Header = extern struct {
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

    fn fromBytes(dtb: [*]const u8) Header {
        var result: Header = undefined;
        const slice = dtb[0..@sizeOf(Header)];
        std.mem.copyForwards(u8, std.mem.asBytes(&result), slice);

        inline for (std.meta.fields(Header)) |field| {
            const big_endian = @field(result, field.name);
            @field(result, field.name) = std.mem.bigToNative(u32, big_endian);
        }

        return result;
    }

    fn isVerified(self: * const Header) bool {
        return self.magic == 0xd00dfeed;
    }
};

const Structs = struct {
    elts: []const u32,

    fn fromSlice(data: []const u8) Structs {
        const len = data.len / @sizeOf(u32);

        const u32_ptr = @as(
            [*]const u32,
            data.ptr
        );

        return Structs {
            .elts = u32_ptr[0..len]
        };
    }
};

const Strings = struct {
    elts: []const u8,

    fn fromSlice(data: []const u8) Strings {
        return Strings {
            .elts = data
        };
    }
};

const MemRsvMap = struct {
    elts: [*]const u64,
};

const DtbParser = struct {
    header: Header,
};
