ENTRY(_start)

/* RAM starts at 0x80000000 */
. = 0x80000000;

SECTIONS {
  .init : ALIGN(4K) {
    PROVIDE(__init_start = .);
    *(.init);
    PROVIDE(__init_end = .);
  }
  .text : ALIGN(4K) {
    PROVIDE(__text_start = .);
    *(.text);
    PROVIDE(__text_end = .);
  }
  .rodata : ALIGN(4K) {
    PROVIDE(__rodata_start = .);
    *(.rodata);
    PROVIDE(__rodata_end = .);
  }
  .data : ALIGN(4K) {
    PROVIDE(__data_start = .);
    *(.data);
    PROVIDE(__data_end = .);
  }
  .bss : ALIGN(4K) {
    PROVIDE(__bss_start = .);
    *(.bss);
    PROVIDE(__bss_end = .);
  }
  PROVIDE(__global_pointer = .);
  PROVIDE(__heap_start = .);
  . = 0x88000000;
  PROVIDE(__kernel_stack_start = . - 0x80000);
  PROVIDE(__kernel_stack_end = .);
  PROVIDE(__heap_size = __kernel_stack_start - __heap_start);
}
