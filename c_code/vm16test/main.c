#include <stdio.h>
#include <stdlib.h>
#include "../vm16/vm16.h"

#define MEM_SIZE       (12)
#define CYCLES         (1000000)

uint16_t code[] = {
0x1010, 0x1111, 0x1030, 0x2222, 0x1050, 0x3333, 0x1070, 0x4444,
0x7000, 0x2001, 0x2462, 0x2870, 0x0003, 0x2C10, 0x0003, 0x7000,
0x0A00, 0x0023, 0x0000, 0x5A00, 0x0017, 0x4010, 0x0025, 0x7000,
0x5A00, 0x001C, 0x4810, 0x0027, 0x5A00, 0x0020, 0x4C10, 0x0029,
0x7000, 0x1600, 0x002C, 0x1800, 0x0C00, 0x680D, 0x0C00, 0x3C00,
0x0C00, 0x3810, 0xFFFF, 0x0C00, 0x0400
};

int main()
{
    uint32_t ran;
    uint32_t size = vm16_calc_size(MEM_SIZE);
    vm16_t *C = (vm16_t *)malloc(size);
    vm16_init(C, size);
    vm16_write_mem(C, 0, sizeof(code) / 2, code);
    while(vm16_run(C, 1, &ran) != VM16_HALT) {
        printf("A:%04X B:%04X C:%04X D:%04X X:%04X Y:%04X PC:%04X SP:%04X\n", C->areg, C->breg, C->creg, C->dreg, C->xreg, C->yreg, C->pcnt, C->sptr);
    }
    free(C);
    return 0;
}
