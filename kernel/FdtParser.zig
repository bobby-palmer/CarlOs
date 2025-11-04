/// Fdt parser following
/// https://devicetree-specification.readthedocs.io/en/stable/flattened-format.html
const FdtParser = @This();

const std = @import("std");
const common = @import("common.zig");

header: Header,
root: StructNode,
mem_rsv_map: std.ArrayList(common.MemorySpan),

/// Parse fdt
pub fn parse(fdt: [*]const u64, alloc: std.mem.Allocator) !FdtParser {
    const header = Header.from_fdt(fdt);

    const strings = Strings {
        .bytes = @as([*]const u8, @ptrCast(fdt)) + header.off_dt_strings
    };

    const words = @as([*]const u32, @ptrCast(fdt)) + 
        header.off_dt_struct / @sizeOf(u32);
    const root, _ = try StructNode.parse(words, &strings, alloc);

    var mem_rsv_head = fdt + header.off_mem_rsvmap / @sizeOf(u64);
    var mem_rsv_lst = try std.ArrayList(common.MemorySpan).initCapacity(alloc, 10);

    while (true) {
        const start = std.mem.bigToNative(u64, mem_rsv_head[0]);
        mem_rsv_head += 1;
        const len = std.mem.bigToNative(u64, mem_rsv_head[0]);
        mem_rsv_head += 1;

        if (start == 0 and len == 0) break;

        _ = try mem_rsv_lst.append(alloc, common.MemorySpan { 
            .start = start, 
            .end = start + len,
        });
    }

    return FdtParser {
        .header = header,
        .root = root,
        .mem_rsv_map = mem_rsv_lst
    };
}

/// Free allocated memory used for parsing
pub fn deinit(self: *FdtParser, allocator: std.mem.Allocator) void {
    self.root.deinit(allocator);
    self.mem_rsv_map.deinit(allocator);
}

/// Print out the device tree for debugging
pub fn write(self: *const FdtParser, writer: *std.io.Writer) !void {
    try writer.writeAll("==== FDT =====\n");

    try writer.writeAll("=== HEADER ===\n");
    try self.header.write(writer);
    try writer.writeByte('\n');

    try writer.writeAll("==== Tree ====\n");
    try self.root.write(writer, 0);
    try writer.writeByte('\n');

    try writer.writeAll("= MemRsvMap ==\n");
    for (self.mem_rsv_map.items) |entry| {
        try writer.print("start: 0x{x}, len: 0x{x}\n", .{ entry.start, entry.len} );
    }
    try writer.writeByte('\n');
}

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

    fn from_fdt(fdt: [*]const u64) Header {
        var header = @as(*const Header, @ptrCast(@alignCast(fdt))).*;

        inline for (std.meta.fields(Header)) |field| {
            @field(header, field.name) = 
                std.mem.bigToNative(u32, @field(header, field.name));
        }

        return header;
    }

    fn write(self: *const Header, writer: *std.io.Writer) !void {
        inline for (std.meta.fields(Header)) |field| {
            try writer.print("{s}: 0x{x}\n", .{ field.name, @field(self, field.name)});
        }
    }

    pub fn isVerified(self: *const Header) bool {
        return self.magic == 0xd00dfeed;
    }

}; // Header

pub const StructNode = struct {

    const FDT_BEGIN_NODE: u32 = 0x1;
    const FDT_END_NODE: u32 = 0x2;
    const FDT_PROP: u32 = 0x3;
    const FDT_NOP: u32 = 0x4;
    const FDT_END: u32 = 0x9;

    pub const PropNode = struct {
        name: []const u8,
        value: []const u8,
    };

    name: []const u8,
    props: std.ArrayList(PropNode),
    sub_nodes: std.ArrayList(StructNode),

    fn write(self: *const StructNode, writer: *std.io.Writer, depth: usize) !void {
        try writer.splatByteAll(' ', depth);
        try writer.print("{s}\n", .{self.name});

        if (self.props.items.len > 0) {
            try writer.splatByteAll(' ', depth);
            try writer.writeAll("> Props:\n");

            for (self.props.items) |*prop| {
                try writer.splatByteAll(' ', depth + 2);
                try writer.print("{s}: {s}\n", .{prop.name, prop.value});
            }
        }

        if (self.sub_nodes.items.len > 0) {
            try writer.splatByteAll(' ', depth);
            try writer.writeAll("> Sub Nodes:\n");

            for (self.sub_nodes.items) |*sub_node| {
                try sub_node.write(writer, depth + 5);
            }
        }

        try writer.writeByte('\n');
    }

    /// return value of property if it exists in this node
    pub fn getProp(self: *const StructNode, prop_name: []const u8) ?[]const u8 {
        for (self.props.items) |prop| {
            if (std.mem.eql(u8, prop.name, prop_name)) {
                return prop.value;
            }
        }

        return null;
    }

    /// Return name string after trimming '@' and suffix if present
    pub fn getUnitName(self: *const StructNode) []const u8 {
        if (std.mem.indexOfScalar(u8, self.name, '@')) |idx| {
            return self.name[0..idx];
        } else {
            return self.name;
        }
    }

    fn parse(
        words: [*]const u32, 
        strings: *const Strings, 
        allocator: std.mem.Allocator
    ) !struct {StructNode, [*]const u32} {

        var head = words;

        while (std.mem.bigToNative(u32, head[0]) != FDT_BEGIN_NODE) {
            head += 1;
        }

        head += 1; // Move to start of name

        const cstr: [*:0]const u8 = @ptrCast(head);
        const name: []const u8 = std.mem.span(cstr);

        const name_len = name.len + 1; // include null

        head += if (name_len % 4 == 0) name_len / 4 else name_len / 4 + 1;

        var props = try std.ArrayList(PropNode).initCapacity(allocator, 10);
        var sub_nodes = try std.ArrayList(StructNode).initCapacity(allocator, 10);

        while (true) {
            const token = std.mem.bigToNative(u32, head[0]);

            if (token == FDT_NOP) {
                head += 1;
            }

            else if (token == FDT_PROP) {
                head += 1;

                const len = std.mem.bigToNative(u32, head[0]);
                head += 1;

                const nameoff = std.mem.bigToNative(u32, head[0]);
                head += 1;

                const prop_name = strings.offToStr(nameoff);

                const value = @as([*]const u8, @ptrCast(head))[0..len];
                head += if (len % 4 == 0) len / 4 else len / 4 + 1;

                _ = try props.append(allocator, .{ 
                    .name = prop_name, 
                    .value = value 
                });
            }

            else if (token == FDT_BEGIN_NODE) {
                const sub_node, const end = try 
                    StructNode.parse(head, strings, allocator);
                _ = try sub_nodes.append(allocator, sub_node);
                head = end;
            } 

            else if (token == FDT_END_NODE) {
                head += 1;
                break;
            }

            else {
                @panic("Unexpected token in fdt");
            }
        }

        return .{
            StructNode {
                .name = name,
                .props = props,
                .sub_nodes = sub_nodes,
            },
            head,
        };
    } // parse(...)

    fn deinit(self: *StructNode, allocator: std.mem.Allocator) void {
        for (self.sub_nodes.items) |*sub_node| {
            sub_node.deinit(allocator);
        }

        self.props.deinit(allocator);
        self.sub_nodes.deinit(allocator);
    } // deinit(...)

}; // StructNode

const Strings = struct {
    bytes: [*]const u8,

    fn offToStr(self: *const Strings, offset: usize) []const u8 {
        const ptr: [*:0]const u8 = @ptrCast(self.bytes + offset);
        return std.mem.span(ptr);
    } // offToStr(...)

}; // Strings
