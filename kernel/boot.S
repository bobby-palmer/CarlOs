.equ PAGE_SHIFT, 12
.equ PTE_VALID, 1 << 0
.equ PTE_READ, 1 << 1
.equ PTE_WRITE, 1 << 2
.equ PTE_EXECUTE, 1 << 3

.section .text.boot
.global _start

_start:

.macro PPN, reg, label
  la \reg, \label 
  srli \reg, \reg, PAGE_SHIFT
.endm

/*t0 should have va, t1 should have ppn*/
.macro PTE_SET, pt, lvl, flags
  srli t0, t0, (PAGE_SHIFT + 9 * \lvl)
  andi t0, t0, (1 << 9) - 1
  slli t0, t0, 3

  la t2, \pt
  add t0, t0, t2

  slli t1, t1, 10
  addi t1, t1, \flags

  sd t1, 0(t0)
.endm

  /*Identity mapping*/
  la t0, _RAM_START
  PPN t1, _page_id_lvl2
  PTE_SET _page_kernel_lvl3, 3, PTE_VALID

  la t0, _RAM_START
  PPN t1, _RAM_START
  PTE_SET _page_id_lvl2, 2, PTE_VALID | PTE_EXECUTE | PTE_READ | PTE_WRITE

  /*higher half mapping*/
  la t0, vrs
  ld t0, 0(t0)
  PPN t1, _page_higher_lvl2
  PTE_SET _page_kernel_lvl3, 3, PTE_VALID

  la t0, vrs
  ld t0, 0(t0)
  PPN t1, _RAM_START
  PTE_SET _page_higher_lvl2, 2, PTE_VALID | PTE_EXECUTE | PTE_READ | PTE_WRITE

  /*Start MMU*/
  li t1, 9
	slli t1, t1, 60
	PPN t0, _page_kernel_lvl3
	or t0, t0, t1
	csrw satp, t0

  /*Set stack pointer*/
  la t0, stack_top
  ld sp, 0(t0)

  /*Jump to higher half*/
  la t0, kmain
  ld t0, 0(t0)
  jalr x0, t0, 0

.macro DEFINE_PAGE, name
.align PAGE_SHIFT
\name: 
.rep (1 << PAGE_SHIFT)
    .byte 0
.endr
.endm

DEFINE_PAGE _page_kernel_lvl3
DEFINE_PAGE _page_id_lvl2
DEFINE_PAGE _page_higher_lvl2

vrs: .quad _VIRTUAL_RAM_START
stack_top: .quad _stack_top
kmain: .quad _kmain
