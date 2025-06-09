ENTRY(boot)

SECTIONS {
  /* Start after OpenSBI */
  . = 0x80200000;

  PROVIDE(__kernel_start = .);

  .text : ALIGN(4K) {
    KEEP(*(.text.boot))
    *(.text .text.*)
  }

  .text.trap : ALIGN(4) {
    *(.text.trap)
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
    PROVIDE(__bss_start = .);
    *(.sbss .sbss.*)
    *(.bss .bss.*)
    PROVIDE(__bss_end = .);
  }

  PROVIDE(__kernel_end = ALIGN(4K));
}
