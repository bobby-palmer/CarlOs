#include <stdint.h>

extern char __end[];

void __attribute__((naked)) boot(void) {
  __asm__ __volatile__(
    "mv   t0, a0    \n"   // move hart_id to t0
    "addi t0, t0, 1 \n"   // increment hart_id
    "slli t0, t0, 12\n"   // multiply by 4KB (stack size)
    "la   t1, __end\n"// load ram start
    "add  sp, t0, t1\n"   // load to stack pointer
    "j kmain\n"           // call kmain
  );
}

void kmain(uint64_t hart_id, void *dtb)
{
  for(;;);
}

