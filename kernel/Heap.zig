//! Slab based heap allocator

const Heap = @This();

const std = @import("std");
const common = @import("common.zig");
const pmm = @import("pmm.zig");
const Spinlock = @import("Spinlock.zig");

caches: [MAX_ALLOCATION_ORDER - MIN_ALLOCATION_ORDER + 1]std.DoublyLinkedList 
    = .{std.DoublyLinkedList{}} ** (MAX_ALLOCATION_ORDER - MIN_ALLOCATION_ORDER + 1),

fn genericAlloc(
    self: *anyopaque, 
    len: usize, 
    alignment: std.mem.Alignment, 
    ret_addr: usize) ?[*]u8 {
    
    const heap: *Heap = @ptrCast(self);
    return heap.alloc(len, alignment, ret_addr);
}

pub fn alloc(
    self: *Heap, 
    len: usize, 
    alignment: std.mem.Alignment, 
    ret_addr: usize) ?[*]u8 {
    
    _ = ret_addr;

    const bytes_order = getAllocationOrder(len, alignment);

    if (bytes_order > MAX_ALLOCATION_ORDER) {

        const pages = getPageOrder(bytes_order);
        const page = pmm.alloc(pages) catch return null;
        return @ptrFromInt(page.startAddr());

    } else {

        const cache_idx = bytes_order - MIN_ALLOCATION_ORDER;

        if (self.caches[cache_idx].first == null) {

            const page = pmm.allocPage() catch return null; 

            page.data = .{ .heap = .{} };

            var current_addr = page.startAddr();
            while (current_addr < page.endAddr()) 
                : (current_addr += @as(usize, 1) << @intCast(bytes_order)) {
                
                const node: *std.SinglyLinkedList.Node = @ptrFromInt(current_addr);
                page.data.heap.free_slots.prepend(node);
            }

            self.caches[cache_idx].prepend(&page.data.heap.cache_link);

        }

        const node = self.caches[cache_idx].first orelse unreachable;
        
        const page = common.nestedFieldParentPtr(
            pmm.Page, 
            &.{"data", "heap", "cache_link"}, 
            node);

        const slot = page.data.heap.free_slots.popFirst() orelse unreachable;

        page.data.heap.used_slots += 1;

        if (page.data.heap.free_slots.first == null) {
            _ = self.caches[cache_idx].popFirst();
        }

        return @ptrCast(slot);

    }
}

fn genericFree(
    self: *anyopaque, 
    memory: []u8, 
    alignment: std.mem.Alignment, 
    ret_addr: usize) void {

    const heap: *Heap = @ptrCast(self);
    heap.free(memory, alignment, ret_addr);
}

pub fn free(
    self: *Heap, 
    memory: []u8, 
    alignment: std.mem.Alignment, 
    ret_addr: usize) void {

    _ = ret_addr;

    const bytes_order = getAllocationOrder(memory.len, alignment);

    if (bytes_order > MAX_ALLOCATION_ORDER) {

        const page = pmm.pageOfAddress(@intFromPtr(memory.ptr)) 
            orelse unreachable;

        pmm.free(page);

    } else {

        const cache_idx = bytes_order - MIN_ALLOCATION_ORDER;

        const ppn = common.pageDown(@intFromPtr(memory.ptr));
        const slab_page = pmm.pageOfAddress(common.addrOfPage(ppn)) 
            orelse unreachable;

        // Slab unused, return it to pmm
        if (slab_page.data.heap.used_slots == 1) {
            self.caches[cache_idx].remove(&slab_page.data.heap.cache_link);
            pmm.free(slab_page);
            return;
        } 

        // Previously full slab, return to the partial list
        if (slab_page.data.heap.free_slots.first == null) {
            self.caches[cache_idx].append(&slab_page.data.heap.cache_link);
        } 

        slab_page.data.heap.used_slots -= 1;
        slab_page.data.heap.free_slots.prepend(@ptrCast(@alignCast(memory.ptr)));

    }
}

const Allocator = std.mem.Allocator;

pub fn allocator(self: *Heap) Allocator {
    return Allocator {
        .ptr = @ptrCast(self),
        .vtable = &Allocator.VTable {
            .alloc = genericAlloc,
            .free = genericFree,
            .remap = Allocator.noRemap,
            .resize = Allocator.noResize,
        }
    };
}

var lock = Spinlock{};
var global_heap = Heap{};

fn globalAlloc(
    self: *anyopaque, 
    len: usize, 
    alignment: std.mem.Alignment, 
    ret_addr: usize) ?[*]u8 {

    _ = self;
    
    lock.lock();
    defer lock.unlock();

    return global_heap.alloc(len, alignment, ret_addr);
}

fn globalFree(
    self: *anyopaque, 
    memory: []u8, 
    alignment: std.mem.Alignment, 
    ret_addr: usize) void {

    _ = self;

    lock.lock();
    defer lock.unlock();

    global_heap.free(memory, alignment, ret_addr);
}

/// Shared global slab allocator protected by a spinlock
pub const global_allocator = Allocator {
    .ptr = undefined,
    .vtable = &Allocator.VTable {
        .alloc = globalAlloc,
        .free = globalFree,
        .remap = Allocator.noRemap,
        .resize = Allocator.noResize,
    }
};

/// Return the min byte order (1<<order bytes) needed to accomodate this
/// request.
fn getAllocationOrder(len: usize, alignment: std.mem.Alignment) u8 {
    const len_order = std.math.log2_int_ceil(usize, len);
    const align_order = std.math.log2_int_ceil(usize, alignment.toByteUnits());

    return @max(len_order, align_order, MIN_ALLOCATION_ORDER);
}

/// Number of pages needed for 2^order bytes
fn getPageOrder(byte_order: u8) u8 {
    const page_order = std.math.log2_int(u32, common.PAGE_SIZE);

    if (page_order >= byte_order) {
        return 0;
    } else {
        return byte_order - page_order;
    }
}

/// Need at least space for the list nodes within the buffer
const MIN_ALLOCATION_ORDER: u8 = std.math.log2_int_ceil(
    usize,
    @sizeOf(std.SinglyLinkedList.Node)
);

/// Should just allocate whole page if cant fit atleast 2 per page
const MAX_ALLOCATION_ORDER: u8 = std.math.log2_int(
    u32,
    common.PAGE_SIZE / 2
);
