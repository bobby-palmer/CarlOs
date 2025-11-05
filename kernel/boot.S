.section .text.boot
.global _start
  
_start:
  la t0, __kend
.L:
  wfi
  j .L
