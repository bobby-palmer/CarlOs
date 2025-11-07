//! Kernel shared slab allocator

const std = @import("std");
const pmm = @import("pmm.zig");
const common = @import("common.zig");

const Allocator = std.mem.Allocator;
const Alignment = std.mem.Alignment;

pub const gpa = Allocator {
    .ptr = undefined,
    .vtable = Allocator.VTable {
        .alloc = alloc,
        .resize = Allocator.noResize,
        .remap = Allocator.noRemap,
        .free = free,
    }
};

fn alloc(_: *anyopaque, len: usize, alignment: Alignment, ret_addr: usize) ?[*]u8 {
    _ = len;
    _ = alignment;
    _ = ret_addr;

    return null;
}

fn free(_: *anyopaque, memory: []u8, alignment: Alignment, ret_addr: usize) void {
    _ = memory;
    _ = alignment;
    _ = ret_addr;
}

fn getByteAllocationOrder(len: usize, alignment: Alignment) u8 {
    const len_order = std.math.log2_int_ceil(usize, len);
    const align_order = std.math.log2_int_ceil(usize, alignment.toByteUnits());
    return @max(len_order, align_order);
}

const PAGES_PER_SLAB: u8 = 4;
const SLAB_SIZE: usize = PAGES_PER_SLAB * common.constants.PAGE_SIZE;

var next_voffset: usize = 0;

/// Map 8 pages and return start addr
fn expandHeapArea() !usize {
    var ppns: [PAGES_PER_SLAB]common.Paddr = undefined;
    var idx: usize = 0;

    errdefer {
        for (0..idx) |i| {
            pmm.freePage(ppns[i]);
        }
    }

    while (idx < PAGES_PER_SLAB) : (idx += 1) {
        ppns[idx] = try pmm.allocPage();
    }

    unreachable; // TODO

    // const base_addr = next_voffset + common.constants.KHEAP_BASE;
    // next_voffset += PAGES_PER_SLAB * common.constants.PAGE_SIZE;
    // return base_addr;
}

/// Allocator for buffers of size and alignment 2^order
const Cache = struct {
    order: u8,
    slabs_full: std.DoublyLinkedList = .{},
    slabs_partial: std.DoublyLinkedList = .{},
    slabs_empty: std.DoublyLinkedList = .{},


    const Slab = struct {
        node: std.DoublyLinkedList.Node = .{},
        free_list: std.SinglyLinkedList = .{},
        free_slots: usize = 0,

        fn allocate(self: *const Slab) *anyopaque {
            std.debug.assert(self.free_slots > 0);
            self.free_slots -= 1;

            return @ptrCast(
                self.free_list.popFirst() orelse unreachable
            );
        }

        fn free(self: *const Slab, ptr: *anyopaque) void {
            self.free_slots += 1;
            self.free_list.prepend(@ptrCast(ptr));
        }

        /// Construct slab in place in memory buffer
        fn init(base_addr: usize, size: usize) *Slab {
            const me: *Slab = @ptrFromInt(base_addr);
            me = .{};

            var head = base_addr + @sizeOf(Slab);
            head = std.mem.alignForward(usize, head, size);

            while (head < base_addr + SLAB_SIZE) : (head += size) {
                me.free(@ptrFromInt(head));
            }
        }
    };

    fn allocate(self: *const Cache) !*anyopaque {
        if (self.slabs_partial.first) |node| {

            const slab: *Slab = @fieldParentPtr("node", node);
            const result = slab.allocate();

            if (slab.free_slots == 0) {
                self.slabs_partial.remove(node);
                self.slabs_full.append(node);
            }

            return result;

        } else if (self.slabs_empty.popFirst()) |node| {

            const slab: *Slab = @fieldParentPtr("node", node);
            const result = slab.allocate();

            self.slabs_partial.append(node);
            return result;

        } else { // Assumes that slab can fit at least 2 items

            const pages = try expandHeapArea();
            const slab = Slab.init(pages, @as(usize, 1) << self.order);
            const result = slab.allocate();
            self.slabs_partial.append(&slab.node);
            return result;

        }
    }

    fn free(self: *const Cache, addr: *anyopaque) void {

    }

    // Add function to take empty slabs
};
