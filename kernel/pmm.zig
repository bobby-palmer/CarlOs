//! Global free page buddy allocator, and metadata manager.

const std = @import("std");
const common = @import("common.zig");

/// Max contiguous allocation is 2^10 pages = 4MB
pub const MAX_ORDER: u8 = 10;

/// Similar to linux struct Page {} this is used to hold various metadatas
/// depending on what component owns the page
pub const Page = struct {

    /// Page status
    flags: struct {
        reserved: u1,
        free: u1,
        is_head: u1,
    },

    /// how many pages are in this group (allocated or free) should not be
    /// modified outside of pmm!
    order: u8,

    /// Phyical page number for this metadata.
    ppn: u64,

    /// Contextual info with each field corresponding to data for a specific
    /// component
    data: union {
        pmm: struct {
            buddy_link: std.DoublyLinkedList.Node = .{},
        },

        heap: struct {
            cache_link: std.DoublyLinkedList.Node = .{},
            free_slots: std.SinglyLinkedList = .{},
            used_slots: usize = 0,
        },
    },

    /// The start address of this page
    pub fn startAddr(self: *const Page) usize {
        return common.addrOfPage(self.ppn);
    }

    /// Return length in bytes of this allocation
    pub fn size(self: *const Page) usize {
        return common.PAGE_SIZE * (@as(usize, 1) << @intCast(self.order));
    }

    /// Return first address after the end of this page region
    pub fn endAddr(self: *const Page) usize {
        return self.startAddr() + self.size();
    }
};

/// Add a contiguous region of ram to the phyical memory manager, marking
/// reservations and freeing the rest of the region. All calls to this should
/// be made before booting other cpus!
pub fn addRam(
    ram: common.MemoryRegion, 
    reserved: []const common.MemoryRegion) void {

    if (next_region_idx >= MAX_REGIONS) {
        return; // pmm can only manage up to MAX_REGIONS non contiguous memory
    }

    const start_ppn = common.pageUp(ram.start);
    const end_ppn = common.pageDown(ram.end());

    var first_free_page = start_ppn;

    for (reserved) |region| {
        first_free_page = @max(first_free_page, common.pageUp(region.end()));
    }

    const metadata_pages = common.pageUp((end_ppn - start_ppn) * @sizeOf(Page));

    if (first_free_page + metadata_pages > end_ppn) {
        return; // Not enough space for metadata
    }

    // Init metadata array

    regions[next_region_idx].start_ppn = start_ppn;

    regions[next_region_idx].pages = 
        @as([*]Page, 
            @ptrFromInt(common.addrOfPage(first_free_page))
        )[0..(end_ppn - start_ppn)];

    next_region_idx += 1;

    // Default init page
    for (start_ppn..end_ppn) |ppn| {
        const page = pageOfPpn(ppn) orelse unreachable;

        page.flags.free = 0;
        page.flags.reserved = 0;
        page.flags.is_head = 1;

        page.order = 0;
        page.ppn = ppn;
    }

    for (reserved) |region| {
        for (common.pageDown(region.start)..common.pageUp(region.end())) |ppn| {
            if (pageOfPpn(ppn)) |page| {
                page.flags.reserved = 1;
            }
        }
    }

    for (first_free_page..first_free_page + metadata_pages) |ppn| {
        const page = pageOfPpn(ppn) orelse unreachable;
        page.flags.reserved = 1;
    }

    for (start_ppn..end_ppn) |ppn| {
        const page = pageOfPpn(ppn) orelse unreachable;

        if (page.flags.reserved == 0) {
            free(page);
        }
    }
}

/// Allocate 2^order pages or error on failure. Return struct for the first in
/// the region
pub fn alloc(order: u8) error{OutOfMemory}!*Page {
    if (order > MAX_ORDER) {
        @panic("pmm MAX_ORDER exceeded");
    }

    lock.lock();
    defer lock.unlock();

    for (order..MAX_ORDER + 1) |order_to_try| {
        if (buddy_lists[order_to_try].pop()) |node| {
            const page = common.nestedFieldParentPtr(
                Page, &.{"data", "pmm", "buddy_link"}, node);

            var current_order = order_to_try;

            while (current_order > order) : (current_order -= 1) {
                const buddy_ppn = buddyOf(page.ppn, @intCast(current_order - 1));
                const buddy_page = pageOfPpn(buddy_ppn) orelse unreachable;

                buddy_page.flags.free = 1;
                buddy_page.flags.is_head = 1;
                buddy_page.order = @intCast(current_order - 1);
                buddy_page.data = .{ .pmm = .{} };

                buddy_lists[current_order - 1].append(&buddy_page.data.pmm.buddy_link);
            }

            page.flags.free = 0;
            page.flags.is_head = 1;
            page.order = order;
            return page;
        }
    }

    return error.OutOfMemory;
}

/// Alloc with order 0 (single page)
pub fn allocPage() error{OutOfMemory}!*Page {
    return alloc(0);
}

/// Free 2^order pages. Must be called on page returned by alloc!
pub fn free(page: *Page) void {

    if (page.flags.is_head == 0) {
        @panic("free called on page that isnt begin of allocation");
    }

    if (page.flags.free == 1) {
        @panic("Double free on page");
    }

    if (page.flags.reserved == 1) {
        @panic("Free called on reserved region");
    }

    lock.lock();
    defer lock.unlock();

    var page_to_free = page;
    var current_order = page.order;

    while (current_order < MAX_ORDER) : (current_order += 1){
        const buddy_ppn = buddyOf(page_to_free.ppn, current_order);
        const buddy_page = pageOfPpn(buddy_ppn) orelse break;

        // Shouldn't be possible to join with another since this is its buddy
        std.debug.assert(buddy_page.flags.is_head == 1);

        if (buddy_page.flags.free == 0 or 
            buddy_page.flags.reserved == 1 or
            buddy_page.order != current_order) break;

        buddy_lists[current_order].remove(&buddy_page.data.pmm.buddy_link);

        page_to_free.flags.is_head = 0;
        buddy_page.flags.is_head = 0;

        if (buddy_page.ppn < page_to_free.ppn) {
            page_to_free = buddy_page;
        }
    }

    page_to_free.flags.free = 1;
    page_to_free.flags.is_head = 1;
    page_to_free.order = current_order;
    page_to_free.data = .{ .pmm = .{} };

    buddy_lists[current_order].append(&page_to_free.data.pmm.buddy_link);
}

/// Return page metadata for page starting at address, if it exists
pub fn pageOfAddress(address: usize) ?*Page {
    if (!std.mem.isAligned(address, common.PAGE_SIZE)) {
        @panic("Invalid page start address");
    }

    return pageOfPpn(common.pageDown(address));
}

fn pageOfPpn(ppn: u64) ?*Page {
    for (getValidRegions()) |region| {
        if (region.containsPpn(ppn)) {
            return region.pageOfPpn(ppn);
        }
    }

    return null;
}

/// Return buddy ppn
fn buddyOf(ppn: u64, order: u8) u64 {
    return ppn ^ (@as(u64, 1) << @intCast(order));
}

/// Slice over initialized regions
fn getValidRegions() []RegionMetadata {
    return regions[0..next_region_idx];
}

const RegionMetadata = struct {
    start_ppn: u64,
    pages: []Page,

    fn endPpn(self: *const RegionMetadata) u64 {
        return self.start_ppn + self.pages.len;
    }

    fn containsPpn(self: *const RegionMetadata, ppn: u64) bool {
        return self.start_ppn <= ppn and ppn < self.endPpn();
    }

    /// Return page metadata for ppn, panic if not in this region
    fn pageOfPpn(self: *const RegionMetadata, ppn: u64) *Page {
        if (!self.containsPpn(ppn)) {
            @panic("Access to page that isnt in region");
        }

        return &self.pages[ppn - self.start_ppn];
    }
};

var next_region_idx: u8 = 0;
const MAX_REGIONS: u8 = 5;
var regions: [MAX_REGIONS]RegionMetadata = undefined;

var lock = Spinlock{};
var buddy_lists = [_]std.DoublyLinkedList {std.DoublyLinkedList {}} **
(MAX_ORDER + 1);
