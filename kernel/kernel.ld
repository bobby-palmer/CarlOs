OUTPUT_ARCH("riscv")
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

  __global_ptr = .;

  .heap : ALIGN(4K) {
    __heap_start = .;
    . += 64K;
    __heap_end = .;
  }

  .stack : ALIGN(4K) {
    . += NUM_CPU * 8K;
    __stack_top = .;
  }
}
