extern char __bss[], __bss_end[], __stack_top[];

void kmain(void) 
{
  for (;;);
}

// Setup stack pointer and jump to kmain
__attribute__((section(".text.boot")))
__attribute__((naked))
void boot(void) 
{
    __asm__ __volatile__(
        "mv sp, %[stack_top]\n"
        "j kmain\n"      
        :
        : [stack_top] "r" (__stack_top)
    );
}
