#include <stdint.h>

extern uint64_t __stack_sz;
extern char __stack_top[];

void init_stack(uint64_t hart_id)
{
  char *stack_top = __stack_top - hart_id * __stack_sz;
  asm volatile (
        "mv sp, %0"  
        :                 // no output
        : "r"(stack_top)  // Input: stack address
        : "sp"            // Clobbered register
    );
}

void kmain(uint64_t hart_id)
{
  init_stack(hart_id);

  for(;;);
}
