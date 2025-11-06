ENTRY(_start);

_RAM_START = 0x80000000;
_KERNEL_START = _RAM_START + 0x200000;
_KERNEL_VIRTUAL_START = 0xFFFF800000000000;

_VMA_OFFSET = _KERNEL_VIRTUAL_START - _KERNEL_START;

SECTIONS {

  . = _KERNEL_START;

  .text.boot ALIGN(4) : {
    KEEP(*(.text.boot))
    _boot_end = .;
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

}
