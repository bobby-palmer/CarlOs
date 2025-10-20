//! Module for small common types to provide compile time checks for correct
//! interpretation of their meaning.

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
};
