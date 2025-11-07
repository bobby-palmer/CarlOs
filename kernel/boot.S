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
  li t0, 0
  li t1, 0
  PTE_SET _kernel_pt, 3, PTE_VALID | PTE_READ | PTE_WRITE | PTE_EXECUTE

  /*Higher half mapping*/
  la t0, vma_offset
  ld t0, 0(t0)
  li t1, 0
  PTE_SET _kernel_pt, 3, PTE_VALID | PTE_READ | PTE_WRITE | PTE_EXECUTE

  /*Start MMU*/
  li t1, 9
	slli t1, t1, 60
	PPN t0, _kernel_pt
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

DEFINE_PAGE _kernel_pt

vma_offset: .quad _VMA_OFFSET
stack_top: .quad _stack_top
kmain: .quad _kmain
