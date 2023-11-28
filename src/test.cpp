#include <stdint.h>

volatile int32_t *a = (volatile int32_t *) 0x1F000;
volatile int32_t *b = (volatile int32_t *) 0x1F004;
volatile int32_t *y = (volatile int32_t *) 0x1F008;

extern "C" void _start(void)
{
    while (true)
    {
        *y = *a + *b;
    }
}
