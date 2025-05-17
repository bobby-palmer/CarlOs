ENTRY(kmain)

SECTIONS {
  /* Start after OpenSBI */
  . = 0x80200000;

  .text : ALIGN(4K) {
    *(.text .text.*)
  }

  .rodata : ALIGN(4K) {
    *(.srodata .srodata.*)
    *(.rodata .rodata.*)
  }

  .data : ALIGN(4K) {
    *(.sdata .sdata.*)
    *(.data .data.*)
  }

  .bss : ALIGN(4K) {
    __bss_start = .;
    *(.sbss .sbss.*)
    *(.bss .bss.*)
    __bss_end = .;
  }
}
