pub const PAGE_SHIFT: u32 = 12; // log2(4096)
pub const PAGE_SIZE: usize = 1 << PAGE_SHIFT; // 4KB

/// Return first page number that starts on or before addr
pub fn pageDown(addr: usize) u64 {
    return addr >> PAGE_SHIFT;
}

/// return first page that starts on or after addr
pub fn pageUp(addr: usize) u64 {
    return (addr + PAGE_SIZE - 1) / PAGE_SIZE;
}
