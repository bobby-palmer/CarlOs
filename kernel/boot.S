.equ PAGE_SHIFT, 12
.equ PTE_VALID, 1 << 0
.equ PTE_READ, 1 << 1
.equ PTE_WRITE, 1 << 2
.equ PTE_EXECUTE, 1 << 3

.section .text.boot
.global _start

_start:

.macro PPN, reg, pt
	la \reg, \pt
	srli \reg, \reg, PAGE_SHIFT
.endm

/* Clobbers: \ppn t0 t1
 * Arguments:
 *   pt: symbol
 *   lvl: immediate
 *   va: register
 *   ppn: register
 *   flags: immediate
 */
.macro PTE_SET, pt, lvl, va, ppn, flags
	/* extract the correct level from \va */
	srli \va, \va, (PAGE_SHIFT + 9 * \lvl)
	andi \va, \va, (1 << 9) - 1
	slli \va, \va, 3

	/* get index in the pte */
	la t0, \pt
	add t0, t0, \va

	/* Transform the PPN into the PTE */
	slli \ppn, \ppn, 10
	addi \ppn, \ppn, \flags

	sw \ppn, 0(t0)
.endm

  /*Disable interupts*/
  csrw sie, 0
	csrw sip, 0

  /*1GB identity mapping*/
  la t1, _RAM_START
  PPN t2, _boot_pt_lvl2
  PTE_SET _kernel_pt_lvl3, 3, t1, t2, PTE_VALID 
  PPN t2, _RAM_START
  PTE_SET _boot_pt_lvl2, 2, t1, t2, PTE_VALID | PTE_EXECUTE | PTE_READ | PTE_WRITE

  /*1GB Higher half mapping*/
  la t1, KVS
  ld t1, 0(t1)
  PPN t2, _code_pt_lvl2 
  PTE_SET _kernel_pt_lvl3, 3, t1, t2, PTE_VALID
  PPN t2, _RAM_START
  PTE_SET _code_pt_lvl2, 2, t1, t2, PTE_VALID | PTE_EXECUTE | PTE_READ | PTE_WRITE

  /*Start mmu with mapping*/
	;  li t1, 9
	; slli t1, t1, 60
	; PPN t0, _kernel_pt_lvl3
	; or t0, t0, t1
	; csrw satp, t0

  /*Verify*/
  li a0, 0xd00dfeed

/*Inf loop*/
.L:
  wfi
  j .L

KVS: .quad _KERNEL_VIRTUAL_START

.macro DEFINE_PAGE, name
.align PAGE_SHIFT
\name: 
.rep (1 << PAGE_SHIFT)
	.byte 0
.endr
.endm


DEFINE_PAGE _kernel_pt_lvl3
DEFINE_PAGE _boot_pt_lvl2
DEFINE_PAGE _code_pt_lvl2
