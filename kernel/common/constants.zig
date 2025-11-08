pub const KB: u32 = 1 << 10;
pub const MB: u32 = 1 << 20;
pub const GB: usize = 1 << 30;

pub const PAGE_SIZE: u32 = 4 * KB;
/// Offset from higher half ram mapping to phyical address
/// Note: this must be in sync with kernel.ld!
pub const VMA_OFFSET: usize = 0xffff800000000000;
/// Base virtual address of the kernel heap address space
pub const KHEAP_BASE: usize = 0xffff900000000000;
/// Max length of the kernel heap space that can be allocated
pub const KHEAP_LEN: usize = 512 * GB;
