#include <stdint.h>

#include "sbi/sbi.h"

#define STACK_SZ 0x4000 // want to remove duplicate definitions

extern char __stack_top[], __bss_start[], __bss_end[];

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

static void init_bss(void)
{
  for (int i = 0; i < __bss_end - __bss_start; ++i) 
  {
    __bss_start[i] = 0;
  }
}

void kmain(uint64_t hart_id)
{
  init_stack(hart_id);

  if (hart_id == 0) 
  {
    init_bss();

    const char Hello[] = "Hello from kmain!";

    for (int i = 0; Hello[i]; ++i) 
    {
      sbi_putchar(Hello[i]);
    }
  }

  for(;;);
}
