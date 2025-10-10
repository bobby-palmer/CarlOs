const std = @import("std");

pub const Fdt = struct {

    pub const Header = extern struct {
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

        fn fromBytes(bytes: [*]const u8) Header {
            var result: Header = undefined;
            const byte_slice = bytes[0..@sizeOf(Header)];

            std.mem.copyForwards(u8, std.mem.asBytes(&result), byte_slice);

            inline for (std.meta.fields(Header)) |field| {
                @field(result, field.name) = std.mem.bigToNative(
                    u32, 
                    @field(result, field.name)
                );
            }

            return result;
        }

        /// Return true if header is valid
        pub fn verify(self: *const Header) bool {
            return self.magic == 0xd00dfeed;
        }
    };

    pub const StructNode = struct {
        const FDT_BEGIN_NODE: u32 = 0x00000001;
        const FDT_END_NODE: u32 = 0x00000002;
        const FDT_PROP: u32 = 0x00000003;
        const FDT_NOP: u32 = 0x00000004;
        const FDT_END: u32 = 0x00000009;

        pub const PropNode = struct {
            name: []const u8,
            value: []const u8,

            fn fromWords(words: [*]const u32, strings: *const Strings) struct {PropNode, [*]const u32} {
                const len = read(words + 1);
                const nameoff = read(words + 2);

                const value_ptr: [*]const u8 = @ptrCast(words + 3);
                const value = value_ptr[0..len];

                const end: [*]const u32 = @ptrFromInt(
                    std.mem.alignForward(usize, @intFromPtr(value.ptr + value.len), @alignOf(u32))
                );

                const node = PropNode {
                    .name = strings.get(nameoff),
                    .value = value,
                };

                return .{ node, end };

            }
        };

        name: []const u8,
        props: std.ArrayList(PropNode),
        sub_nodes: std.ArrayList(StructNode),

        fn read(word: [*]const u32) u32 {
            return std.mem.bigToNative(u32, word[0]);
        }

        fn init(words: [*]const u32, strings: *const Strings, allocator: std.mem.Allocator) !struct {StructNode, [*]const u32} {
            var head = words;

            while (read(head) != FDT_BEGIN_NODE) {
                head += 1;
            }

            head += 1;

            const name_ptr: [*:0]const u8 = @ptrCast(head);
            const name: []const u8 = std.mem.span(name_ptr);

            head = @ptrFromInt(
                std.mem.alignForward(usize, @intFromPtr(name.ptr + name.len + 1), @alignOf(u32))
            );

            var props = try std.ArrayList(PropNode).initCapacity(allocator, 10);
            var sub_nodes = try std.ArrayList(StructNode).initCapacity(allocator, 10);

            while (true) {
                const token = read(head);

                if (token == FDT_NOP) {
                    head += 1;
                }
                else if (token == FDT_PROP) {
                    const res = PropNode.fromWords(head, strings);
                    try props.append(allocator, res.@"0");
                    head = res.@"1";
                } else if (token == FDT_BEGIN_NODE) {
                    const res = try StructNode.init(head, strings, allocator);
                    try sub_nodes.append(allocator, res.@"0");
                    head = res.@"1";
                } else if (token == FDT_END_NODE) {
                    break;
                }
            }

            const node = StructNode {
                .name = name,
                .props = props,
                .sub_nodes = sub_nodes,
            };

            return .{ node, head + 1};
        }
    };

    const Strings = struct {
        data: [*]const u8,
        fn get(self: *const Strings, offset: usize) []const u8 {
            const ptr: [*:0]const u8 = @ptrCast(self.data + offset);
            return std.mem.span(ptr);
        }
    };

    header: Header,
    root: StructNode,

    pub fn init(bytes: [*]const u8, allocator: std.mem.Allocator) !Fdt {
        const header = Header.fromBytes(bytes);
        const strings = Strings {.data = bytes + header.off_dt_strings};

        const struct_ptr: [*]const u32 = @ptrCast(@alignCast(bytes + header.off_dt_struct));
        const root = try StructNode.init(struct_ptr, &strings, allocator);

        return Fdt {
            .header = header,
            .root = root.@"0",
        };
    }
};
