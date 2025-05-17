#include <stdint.h>

// want to remove duplicate definitions 
// using extern char with STACK_SZ = &ch
#define STACK_SZ 0x4000 

extern char __stack_top[], __bss_start[], __bss_end[];

// set stack pointer
static void init_stack(uint64_t hart_id) 
{
  char *stack_top = __stack_top - hart_id * STACK_SZ;
  asm volatile (
        "mv sp, %0"  
        :                 // no output
        : "r"(stack_top)  // Input: stack address
        : "sp"            // Clobbered register
    );
}

// FLOW:
// - OpenSBI hart 0 init
//    - Zero bss
//    - Setup stack
//    - setup heap
// - Allow rest to leave parkinglot
// TODO: add device tree here
void kmain(uint64_t hart_id)
{
  for(;;);
}
