.section .text.boot
.global _start
  
_start:
  la t0, kend
  ld t1, 0(t0)
.L:
  wfi
  j .L

kend: 
  .quad __kend
