ENTRY(_start);

_KERNEL_START = 0x80200000;
_VMA_OFFSET = 0xffff800000000000;
_STACK_LEN = 2M;

SECTIONS {

  . = _KERNEL_START;

  .text.boot : {
    *(.text.boot);
  }
  
  . += _VMA_OFFSET;

  .text : AT(ADDR(.text) - _VMA_OFFSET) {
    *(text .text.*);
  }

  .rodata ALIGN(8) : AT(ADDR(.rodata) - _VMA_OFFSET) {
    *(.srodata .srodata.*);
    *(.rodata .rodata.*);
    . = ALIGN(8);
  }

  .data ALIGN(8) : AT(ADDR(.data) - _VMA_OFFSET) {
    *(.data .data.*);
  }

  .bss ALIGN(64) (NOLOAD) : {
    _sbss = .;
    *(.sbss .sbss.* .bss .bss.*);
    . = ALIGN(64);
    _ebss = .;
  }

  .stack ALIGN(16) (NOLOAD) : {
    . += _STACK_LEN;
    _stack_top = .;
  }

  _kend = .;
}
