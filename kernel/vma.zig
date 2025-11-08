//! Kernel virtual space allocator: This module handles allocating the address
//! space for the kernel. This is not atomic safe, lock should be held by caller 
//! (kmalloc)

const std = @import("std");
const pmm = @import("pmm.zig");
const common = @import("common.zig");

const c = common.constants;

pub fn init() void {
    free(c.KHEAP_BASE, c.KHEAP_LEN / c.PAGE_SIZE);
}

pub fn alloc(num_pages: usize) usize {
    var parent = &free_list;

    while (parent.next) |node| : (parent = node) {

        if (num_pages <= node.len) {
            node.len -= num_pages;
            const base_page = node.endPage();

            if (node.len == 0) {
                parent.next = node.next;
                freeNode(node);
            }
            
            return base_page * c.PAGE_SIZE;
        }
    }

    @panic("No space to allocate");
}

pub fn free(base_addr: usize, num_pages: usize) void {
    const base_page_num = base_addr / c.PAGE_SIZE;

    var parent = &free_list;

    while (parent.next != null and parent.next.?.start_page_num < base_page_num)
        : (parent = parent.next.?) {}

    // Backwards coalese
    if (base_page_num == parent.endPage()) {
        parent.len += num_pages;
    } else {
        const new_node = allocNode();
        new_node.start_page_num = base_page_num;
        new_node.len = num_pages;

        new_node.next = parent.next;
        parent.next = new_node;

        parent = new_node;
    }

    // Forwards coalese
    if (parent.next) |child| {
        if (parent.endPage() == child.start_page_num) {
            parent.len += child.len;
            parent.next = child.next;
            freeNode(child);
        }
    }
}

const Node = struct {
    start_page_num: usize = 0,
    len: usize = 0, // In pages
    next: ?*Node = null,

    fn endPage(self: *const Node) usize {
        return self.start_page_num + self.len;
    }
};

var free_list = Node{};

// ======== Make shift allocator for bookkeeping ============

fn allocNode() *Node {
    if (empty.next == null) {
        const page = pmm.allocPage() catch @panic("VMA out of memory");
        
        var ptr = page.getVaddr();
        const end = ptr + c.PAGE_SIZE;

        while (ptr + @sizeOf(Node) <= end) : (ptr += @sizeOf(Node)) {
            freeNode(@ptrFromInt(ptr));
        }
    }

    const node = empty.next orelse unreachable;
    empty.next = node.next;

    node.* = .{};
    return node;
}

fn freeNode(node: *Node) void {
    node.next = empty.next;
    empty.next = node;
}

var empty = Node{};
