//! Module for small common types to provide compile time checks for correct
//! interpretation of their meaning.

const constants = @import("constants.zig");

/// Physical address type
pub const PAddr = struct {
    addr: usize,

    pub fn new(addr: usize) @This() {
        return @This() {
            .addr = addr
        };
    }
};

/// Virtual address type
pub const VAddr = struct {
    addr: usize,

    pub fn new(addr: usize) @This() {
        return @This() {
            .addr = addr
        };
    }

    pub fn vpn(self: @This(), index: u32) u9 {
        return @intCast(
            // extract 9 bits at index
            (self.addr >> @intCast(12 + 9 * index)) & 0x1FF
        );
    }

    /// Return offset from the begining of virtual page that contains this
    /// address
    pub fn pageOffset(self: @This()) usize {
        return self.addr & (constants.PAGE_SIZE - 1);
    }
};
