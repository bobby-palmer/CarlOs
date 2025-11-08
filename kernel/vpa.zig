//! Kernel virtual page allocator. Individual allocator for bookkeeping

const pmm = @import("pmm.zig");
const common = @import("common.zig");

const VMARegion = struct {
    base_addr: usize = 0,
    page_length: usize = 0,
    next: ?*VMARegion = null,
};

var free_regions = VMARegion{};
var unused_nodes = VMARegion{};

fn allocateRegion() *VMARegion {

    if (unused_nodes.next == null) {
        const page = pmm.allocPage() catch @panic("VMA allocation failed");
        const start = page.getVaddr();
        const end = start + common.constants.PAGE_SIZE;

        var head: [*]VMARegion = @ptrFromInt(start);

        while (head + @sizeOf(VMARegion) <= end) : (head += @sizeOf(VMARegion)) {
            head[0].next = unused_nodes.next;
            unused_nodes.next = &head[0];
        }
    }

    const node = unused_nodes.next orelse unreachable;

    unused_nodes.next = node.next;
    node.next = null;
    return node;
}
