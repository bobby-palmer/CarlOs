//! Kernel shared slab allocator

const std = @import("std");
const pmm = @import("pmm.zig");
const vmm = @import("vmm.zig");
const vma = @import("vma.zig");
const common = @import("common.zig");

const c = common.constants;

const Allocator = std.mem.Allocator;
const Alignment = std.mem.Alignment;

pub const gpa = Allocator {
    .ptr = undefined,
    .vtable = &Allocator.VTable {
        .alloc = alloc,
        .resize = Allocator.noResize,
        .remap = Allocator.noRemap,
        .free = free,
    }
};

fn alloc(_: *anyopaque, len: usize, alignment: Alignment, ret_addr: usize) ?[*]u8 {
    _ = ret_addr;

    const byte_order = getByteOrder(len, alignment);

    if (byte_order <= MAX_BYTE_ORDER) {
        return @ptrCast(caches[byte_order - MIN_BYTE_ORDER].alloc());
    } else {
        const pt = vmm.getCurrentPt();
        const pages = common.divCeil(len, c.PAGE_SIZE);
        const vaddr = vma.alloc(pages);

        for (0..pages) |page_offset| {
            const ppage = pmm.allocPage() catch @panic("Kernel heap failure");
            vmm.mapPage(pt, vaddr + page_offset * c.PAGE_SIZE, ppage, vmm.Flags {
                .R = 1,
                .W = 1,
            }) catch @panic("Kernel heap failure");
        }

        return @ptrFromInt(vaddr);
    }
}

fn free(_: *anyopaque, memory: []u8, alignment: Alignment, ret_addr: usize) void {
    _ = ret_addr;

    const byte_order = getByteOrder(memory.len, alignment);

    if (byte_order <= MAX_BYTE_ORDER) {
        caches[byte_order - MIN_BYTE_ORDER].free(@ptrCast(memory.ptr));
    } else {
        const pt = vmm.getCurrentPt();
        const pages = common.divCeil(memory.len, c.PAGE_SIZE);
        const vaddr = @intFromPtr(memory.ptr);

        for (0..pages) |page_offset| {
            const page_vaddr = vaddr + page_offset * c.PAGE_SIZE;
            const ppage = vmm.translate(pt, page_vaddr)
                orelse @panic("Free called on unmapped page");

            pmm.freePage(ppage);
            vmm.unmapPage(pt, page_vaddr);
        }

        vma.free(vaddr, pages);
    }
}

fn getByteOrder(len: usize, alignment: Alignment) u8 {
    const len_order = std.math.log2_int_ceil(usize, len);
    const align_order = std.math.log2_int_ceil(usize, alignment.toByteUnits());
    return @max(len_order, align_order, MIN_BYTE_ORDER);
}

/// One contiguous virtual memory region to allocate from
const Slab = struct {
    /// Link node into cache
    node: std.SinglyLinkedList.Node = .{},
    /// Free slots to allocate
    free_list: std.SinglyLinkedList = .{},
    /// Length of free list
    used_slots: usize = 0,

    /// Get the owning slab of a given allocation
    fn getOwner(ptr: *anyopaque) *Slab {
        const addr = @intFromPtr(ptr);
        const base = 
            std.mem.alignBackward(
                usize, addr, c.PAGE_SIZE);
        return @ptrFromInt(base);
    }

    /// Allocate a slab with slots of size = "size"
    fn init(size: usize) *Slab {
        const vaddr = vma.alloc(1);
        const paddr = pmm.allocPage() 
            catch @panic("Kmalloc failed");

        const pt = vmm.getCurrentPt();
        vmm.mapPage(pt, vaddr, paddr, vmm.Flags {
            .R = 1,
            .W = 1,
        }) catch @panic("Kmalloc failed");

        const buffer_end = vaddr + c.PAGE_SIZE;

        const me: *Slab = @ptrFromInt(vaddr);
        me.* = .{};

        var head = vaddr + @sizeOf(Slab);
        head = std.mem.alignForward(usize, head, size);

        while (head + size <= buffer_end) : (head += size) {
            const node: *std.SinglyLinkedList.Node = @ptrFromInt(head);
            me.free_list.prepend(node);
        }

        return me;
    }

    fn free(self: *Slab, ptr: *anyopaque) void {
        self.used_slots -= 1;
        self.free_list.prepend(@ptrCast(@alignCast(ptr)));
    }

    fn alloc(self: *Slab) !*anyopaque {
        if (self.free_list.popFirst()) |node| {
            self.used_slots += 1;
            return @ptrCast(node);
        } else {
            return error.OutOfMemory;
        }
    }

    /// return true if no slots left to allocate
    fn isEmpty(self: *const Slab) bool {
        return self.free_list.first == null;
    }
};

const Cache = struct {
    /// Specialized to allocate size bytes
    size: usize,
    partial_slabs: std.SinglyLinkedList = .{},
    empty_slabs: std.SinglyLinkedList = .{},

    fn alloc(self: *Cache) *anyopaque {
        if (self.partial_slabs.first) |node| {

            const slab: *Slab = @fieldParentPtr("node", node);
            const slot = slab.alloc() catch unreachable;

            if (slab.isEmpty()) {
                _ = self.partial_slabs.popFirst();
            }

            return slot;

        } else if (self.empty_slabs.popFirst()) |node| {

            const slab: *Slab = @fieldParentPtr("node", node);
            const slot = slab.alloc() catch unreachable;

            self.partial_slabs.prepend(node);
            return slot;

        } else {
            
            const slab = Slab.init(self.size);
            const slot = slab.alloc() catch unreachable;
            self.partial_slabs.prepend(&slab.node);
            return slot;

        }
    }

    fn free(self: *Cache, ptr: *anyopaque) void {
        const slab = Slab.getOwner(ptr);

        if (slab.isEmpty()) {
            self.partial_slabs.prepend(&slab.node);
        }

        slab.free(ptr);

        if (slab.used_slots == 0) {
            self.empty_slabs.prepend(&slab.node);
        }
    }
};

const MIN_BYTE_ORDER: u8 = 4; // 16B minimum allocation
const MAX_BYTE_ORDER: u8 = 9; // 512B max slab allocation

var caches = blk: {
    var result: [MAX_BYTE_ORDER - MIN_BYTE_ORDER + 1]Cache = undefined;

    for (MIN_BYTE_ORDER..MAX_BYTE_ORDER + 1) |order| {
        result[order - MIN_BYTE_ORDER] = Cache{.size = 1 << order};
    }

    break :blk result;
};
