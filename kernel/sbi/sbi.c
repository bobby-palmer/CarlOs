#include "sbi.h"

void sbi_put_char(char c) {
  register unsigned long a0 asm("a0") = (unsigned long)c;
  register unsigned long a7 asm("a7") = 1;
  asm volatile (
      "ecall"
      : "+r"(a0)
      : "r"(a7)
      : "memory"
  );
}
