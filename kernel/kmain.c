#include "uart/uart.h"

void kmain(void) 
{
  const char hello[] = "Hello World";

  for (int i = 0; i < hello[i]; ++i) {
    kputchar(hello[i]);
  }

  for(;;);
}
