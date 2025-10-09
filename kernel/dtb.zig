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

pub const ReserveEntry = struct {
    address: u64,
    size: u64,
};

const MemRsvIterator = struct {
    elts: [*]const u64,

    pub fn next(self: *MemRsvIterator) ?ReserveEntry {
        const address = std.mem.bigToNative(u64, self.elts[0]);    
        const size = std.mem.bigToNative(u64, self.elts[1]);

        if (address == 0 and size == 0) {
            return null;
        } else {
            self.elts += 2;
            return ReserveEntry {
                .address = address,
                .size = size,
            };
        }
    }
};
