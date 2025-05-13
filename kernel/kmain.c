#include "uart/uart.h"

void kmain(void) 
{

  for (int i = 0; i < 10; ++i) 
  {
    kputchar('a' + i);
  }

  for (;;);
}
