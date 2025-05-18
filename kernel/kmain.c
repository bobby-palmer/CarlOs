#include <stdint.h>

#include "sbi/sbi.h"

extern char __end[];

// Setup stack pointer
void __attribute__((naked)) boot(void) {
  __asm__ __volatile__(
    "mv   t0, a0    \n"   // move hart_id to t0
    "addi t0, t0, 1 \n"   // increment hart_id
    "slli t0, t0, 12\n"   // multiply by 4KB (stack size)
    "la   t1, __end \n"   // load end of kernel memory
    "add  sp, t0, t1\n"   // set stack pointer = base + 4KB * ID
    "j    kmain     \n"   // call kmain
  );
}

extern char __bss_start[], __bss_end[];

void kmain(uint64_t hart_id, void *dtb) {
  
  if (hart_id == 0) {
    for (char *i = __bss_start; i != __bss_end; ++i) 
      *i = 0;

  }

  while (1); // no return
}

