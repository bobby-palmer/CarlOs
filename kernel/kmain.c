void kmain(void) {

}

__attribute__((section(".text.boot")))
__attribute__((naked))
void boot(void) {
  __asm__ __volatile__(
    "mv sp, %[stack_top]\n" // Set the stack pointer
    "j kernel_main\n"       // Jump to the kernel main function
    :
    : [stack_top] "r" (__stack_top) // Pass the stack top address as %[stack_top]
  );
}
