#include <stdint.h>

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
