#include "uart.h"

#define UART_ADDR 0x10000000

static void uart_put(unsigned char c) {
  *(unsigned char *) UART_ADDR = c;
}

int kputchar(int c) {
  uart_put(c);
  return c;
}

void kprint(const char *msg) {
  while (*msg) {
    kputchar(*msg);
    ++msg;
  }
}
