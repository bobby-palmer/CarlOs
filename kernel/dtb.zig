const std = @import("std");

pub const Parser = struct {
    header: Header,
    strings: Strings,
    mem_rsv_block: MemRsvBlock,

    pub fn fromBytes(dtb: [*]const u8) Parser {
        const header = Header.fromBytes(dtb);

        const strings = Strings {
            .data = (dtb + header.off_dt_strings)[0..header.size_dt_strings]
        };

        const mem_rsv = MemRsvBlock {
            .elts = @ptrCast(dtb + header.off_mem_rsvmap)
        };

        return Parser {
            .header = header,
            .strings = strings,
            .mem_rsv_block = mem_rsv,
        };
    }

    // HEADER
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

        /// Return true if header is valid
        pub fn verify(self: * const Header) bool {
            return self.magic == 0xd00dfeed;
        }
    };

    // STRUCTS PARSING
    pub const PropEntry = struct {
        nameoff: u32,
        value: []const u8,
    };

    const StructNode = struct {
        const FDT_BEGIN_NODE: u32 = 0x00000001;
        const FDT_END_NODE: u32 = 0x00000002;
        const FDT_PROP: u32 = 0x00000003;
        const FDT_NOOP: u32 = 0x00000004;
        const FDT_END: u32 = 0x00000009;
    };

    // STRINGS PARSING
    const Strings = struct {
        data: []const u8,

        fn stringOfOff(self: *const Strings, str: []const u8) ?u32 {
            var idx: usize = 0;
            while (idx < self.data.len) {
                const slice_start: [*:0]const u8 = @ptrCast(self.data.ptr + idx);
                const this_slice = std.mem.span(slice_start);

                if (std.mem.eql(u8, str, this_slice)) {
                    return idx;
                } else {
                    idx += this_slice.len + 1; // add one for null char
                }
            }

            return null;
        }

        fn offOfString(self: *const Strings, off: u32) ?[]const u8 {
            if (off >= self.data.len or (off > 0 and self.data[off - 1] != 0)) {
                return null;
            } else {
                const slice_start: [*:0]const u8 = @ptrCast(self.data.ptr + off);
                return std.mem.span(slice_start);
            }
        }
    };

    // MEMORY RESERVE
    pub const ReserveEntry = struct {
        address: u64,
        size: u64,
    };

    const MemRsvBlock = struct {
        elts: [*]const u64,

        pub fn iterator(self: *const MemRsvBlock) MemRsvIterator {
            return MemRsvIterator {
                .elts = self.elts
            };
        }

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
    };
};
