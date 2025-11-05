ENTRY(_start);

PAGESIZE = 4K;

PHYSICAL_BASE = 0x80200000;
VIRTUAL_BASE = 0xFFFFFFFFC0000000;
VMA_OFFSET = VIRTUAL_BASE - PHYSICAL_BASE;

SECTIONS {
  . = PHYSICAL_BASE;

  .text.boot : ALIGN(PAGESIZE) {
    *(.text.boot)
  }

  . = VIRTUAL_BASE + SIZEOF(.text.boot);

  .text : AT(. - VMA_OFFSET) ALIGN(PAGESIZE) {
    *(.text)
  }

  .rodata : AT(. - VMA_OFFSET) ALIGN(PAGESIZE) {
      *(.rodata .rodata.*);
  }

  .data : AT(. - VMA_OFFSET) ALIGN(PAGESIZE) {
      *(.data .data.*);
  }

  .bss : AT(. - VMA_OFFSET) ALIGN(PAGESIZE) {
      __bss = .;
      *(.bss .bss.* .sbss .sbss.*);
      __bss_end = .;
  }

  __kend = ALIGN(PAGESIZE);
}
