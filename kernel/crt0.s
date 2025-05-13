# Disable generation of compressed instructions
# This is to avoid complications when setting values
# of CSRs such as mtvec and stvec which have alignment
# constraints
.option norvc

# Common symbols
.set NUM_GP_REGS, 32
.set REG_SIZE, 8

# Use alternative macro syntax (see GNU assembler docs for details)
.altmacro

# Common macros
.macro save_gp i, basereg=t6
  sd x\i, ((\i) * REG_SIZE)(\basereg)
.endm
.macro load_gp i, basereg=t6
  ld x\i, ((\i) * REG_SIZE)(\basereg)
.endm

# Importation of linker symbols
.section .rodata
.global HEAP_START
HEAP_START: .dword __heap_start

.global HEAP_SIZE
HEAP_SIZE: .dword __heap_size

.global INIT_START
INIT_START: .dword __init_start

.global INIT_END
INIT_END: .dword __init_end

.global TEXT_START
TEXT_START: .dword __text_start

.global TEXT_END
TEXT_END: .dword __text_end

.global RODATA_START
RODATA_START: .dword __rodata_start

.global RODATA_END
RODATA_END: .dword __rodata_end

.global DATA_START
DATA_START: .dword __data_start

.global DATA_END
DATA_END: .dword __data_end

.global BSS_START
BSS_START: .dword __bss_start

.global BSS_END
BSS_END: .dword __bss_end

.global KERNEL_STACK_START
KERNEL_STACK_START: .dword __kernel_stack_start

.global KERNEL_STACK_END
KERNEL_STACK_END: .dword __kernel_stack_end

.section .data
.global KERNEL_TABLE
KERNEL_TABLE: .dword 0

.section .init, "ax"
.global _start
_start:
  # Initialize CSRs for M-mode

  # Supervisor address translation and protection
  # SATP should already be zero, but just to make sure ...
  csrw satp, zero

  # Machine status
  # MPP = mstatus[12:11]
  #      MPP=3 (M-level access with no translation)
  li t0, 0b11 << 11
  csrw mstatus, t0

  # Machine exception program counter
  # Set this to kmain so executing mret jumps to kmain
  la t0, kmain
  csrw mepc, t0

  # Do not allow interrupts in M-mode
  csrw mie, zero

  # Zero the BSS section
  la t0, __bss_start
  la t1, __bss_end
__bss_zero_loop_start:
  bgeu t0, t1, __bss_zero_loop_end
  sd zero, 0(t0)
  addi t0, t0, 8
  j __bss_zero_loop_start
__bss_zero_loop_end:

  # Initialize global pointer register
  .option push
  .option norelax
  la gp, __global_pointer
  .option pop

  # Initialize stack and frame pointer registers
  la sp, __kernel_stack_end
  mv fp, sp

  # If kmain returns, we're done with everything so halt forever
  la ra, halt_forever

  # Now jump to kmain for M-mode initialization
  mret

# We're already done with everything - let's halt forever
halt_forever:
  csrw mie, zero
  wfi
  j halt_forever
