ENTRY(_start);

_RAM_START = 0x80000000;
_KERNEL_START = _RAM_START + 0x200000;

_VIRTUAL_RAM_START = 0xffffffffc0000000;
_VMA_OFFSET = _VIRTUAL_RAM_START - _RAM_START;

_STACK_LEN = 2M;

SECTIONS {

  . = _KERNEL_START;

  .text.boot : {
    _boot_start = .;
    *(.text.boot);
    _boot_end = ABSOLUTE(.);
  }
  
  . = _boot_end + _VMA_OFFSET;

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
