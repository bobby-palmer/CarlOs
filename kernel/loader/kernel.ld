ENTRY(_start)

SECTIONS {
  /* Qemu ram start address */
  . = 0x80000000;

  .text : {
    . = ALIGN(0x1000);
    *(.text .text.*)
  }

  .rodata : ALIGN(16) {
    *(.srodata .srodata.*)
    *(.rodata .rodata.*)
  }

  .data : ALIGN(16) {
    *(.sdata .sdata.*)
    *(.data .data.*)
  }

  .bss : ALIGN(16) {
    __bss_start = .;
    *(.sbss .sbss.*)
    *(.bss .bss.*)
    __bss_end = .;
  }

  .heap : ALIGN(0x1000) {
    __heap_start = .;
    . = . + 0x10000; /* 64 KB heap */
    __heap_end = .;
  }

  .stack : ALIGN(0x1000) {
    __stack_sz = 0x2000; /* 8KB Stack */
    . = . + NUM_CPU * __stack_sz;
    __stack_top = .;
  }

}
