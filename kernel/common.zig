pub const KB: u32 = 1 << 10;
pub const MB: u32 = 1 << 20;

pub const PAGE_SIZE: u32 = 4 * KB;

/// Return first page number that starts on or before addr
pub fn pageDown(addr: usize) u64 {
    return addr / PAGE_SIZE;
}

/// return first page that starts on or after addr
pub fn pageUp(addr: usize) u64 {
    return (addr + PAGE_SIZE - 1) / PAGE_SIZE;
}

/// return address of the start of page
pub fn addrOfPage(page: u64) usize {
    return page * PAGE_SIZE;
}
