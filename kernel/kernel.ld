MEMORY {
  kernel_space (rwx) : ORIGIN = 0x80200000, LENGTH = 16M
}

SECTIONS {
  .text : {
    KEEP(*(.text.boot));
    *(.text .text.*);
  } > kernel_space
}
