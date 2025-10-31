//! Global free page buddy allocator, and metadata manager. 

const std = @import("std");
const common = @import("common.zig");
const Spinlock = @import("Spinlock.zig");

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

    /// how many pages are in this group (allocated or free)
    order: u8,

    /// Phyical page number for this metadata.
    ppn: u64,

    /// Contextual info with each field corresponding to data for a specific
    /// component
    data: union {
        pmm: struct {
            buddy_link: std.DoublyLinkedList.Node,
        },
    },

    /// The start address of this page
    pub fn startAddr(self: *const Page) usize {
        return common.addrOfPage(self.ppn);
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
                Page, [_]u8{"data", "pmm", "buddy_link"}, node);

            var current_order = order_to_try;

            while (current_order > order) : (current_order -= 1) {
                const buddy_ppn = buddyOf(page.ppn, @intCast(current_order - 1));
                const buddy_page = pageOfPpn(buddy_ppn) orelse unreachable;

                buddy_page.flags.free = 1;
                buddy_page.flags.is_head = 1;
                buddy_page.order = @intCast(current_order - 1);
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

    while (current_order < MAX_ORDER) {
        const buddy_ppn = buddyOf(page_to_free.ppn, current_order);
        const buddy_page = pageOfPpn(buddy_ppn) orelse break;

        std.debug.assert(buddy_page.flags.is_head == 1);

        if (buddy_page.flags.free == 0 or 
            buddy_page.order != current_order) break;

        buddy_lists[current_order].remove(&buddy_page.data.pmm.buddy_link);

        page_to_free.flags.is_head = 0;
        buddy_page.flags.is_head = 0;

        if (buddy_page.ppn < page_to_free.ppn) {
            page_to_free = buddy_page;
        }

        current_order += 1;
    }

    page_to_free.flags.free = 1;
    page_to_free.flags.is_head = 1;
    page_to_free.order = current_order;
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
    for (0..next_region_idx) |idx| {
        if (regions[idx].start_ppn <= ppn and ppn < regions[idx].endPpn()) {
            return &regions[idx].pages[ppn - regions[idx].start_ppn];
        }
    }

    return null;
}

/// Return buddy ppn
fn buddyOf(ppn: u64, order: u8) u64 {
    return ppn ^ (@as(u64, 1) << @intCast(order));
}

const RegionMetadata = struct {
    start_ppn: u64,
    pages: []Page,

    fn endPpn(self: *const RegionMetadata) u64 {
        return self.start_ppn + self.pages.len;
    }
};

var next_region_idx: u8 = 0;
const MAX_REGIONS: u8 = 5;
var regions: [MAX_REGIONS]RegionMetadata = undefined;

var lock = Spinlock{};
var buddy_lists = [_]std.DoublyLinkedList {std.DoublyLinkedList {}} ** (MAX_ORDER + 1);
