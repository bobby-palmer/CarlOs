//! Singly linked list for managing raw memory buffers. all buffers must be big
//! enough to store the next pointer

const std = @import("std");
const List = @This();

next: ?*List,

/// Construct empty list
pub fn empty() List {
    return List {
        .next = null
    };
}

/// append buffer to list
pub fn prepend(self: *List, buffer: usize) void {
    const new_node: *List = @ptrFromInt(buffer);
    new_node.next = self.next;
    self.next = new_node;
}

/// remove and return first buffer in list if it exists
pub fn pop(self: *List) ?usize {
    if (self.next) |node| {
        self.next = node.next;
        return @intFromPtr(node);
    } else {
        return null;
    }
}
