MEMORY {
  kernel_space (rwx) : ORIGIN = 0x80200000, LENGTH = 16M
}

SECTIONS {
  __kstart = .;

  .text.boot : {
    *(.text.boot)
  } > kernel_space

  .text : ALIGN(CONSTANT(MAXPAGESIZE)) {
    *(.text)
  } > kernel_space

  .rodata : ALIGN(CONSTANT(MAXPAGESIZE)) {
      *(.rodata .rodata.*);
  } > kernel_space

  .data : ALIGN(CONSTANT(MAXPAGESIZE)) {
      *(.data .data.*);
  } > kernel_space

  .bss : ALIGN(CONSTANT(MAXPAGESIZE)) {
      __bss = .;
      *(.bss .bss.* .sbss .sbss.*);
      __bss_end = .;
  } > kernel_space

  .stack (NOLOAD) : ALIGN(CONSTANT(MAXPAGESIZE)) {
    . = . + 64K;
    __stack_top = .;
  } > kernel_space

  __kend = .;
}
