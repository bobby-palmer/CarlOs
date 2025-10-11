pub const PAGE_SIZE: usize = 4096;

var initialized = false;
var base_addr: usize = undefined;
var bitmap: []u64 = undefined;

/// Round up usize pointer to alignment a
fn alignUp(value: usize, a: usize) usize {
    return (value + a - 1) & ~(a - 1);
}

/// Initialize page allocator if not already initialized
/// Sets up a bitmap and marks the bitmap itself as taken
pub fn init(lowest_addr: usize, highest_addr: usize, highest_reservation_end: usize) void {
    if (initialized) {
        return;
    }

    initialized = true;

    base_addr = alignUp(lowest_addr, PAGE_SIZE);

    const end_addr = alignUp(highest_addr, PAGE_SIZE);
    const num_pages = (end_addr - base_addr) / PAGE_SIZE;
    const nums_needed = (63 + num_pages) / 64;

    const aligned_start = alignUp(highest_reservation_end, PAGE_SIZE);

    bitmap = @intFromPtr(aligned_start)[0..nums_needed];

    @memset(bitmap, 0); // Mark all as taken

    // TODO mark bitmap as taken itself
}
