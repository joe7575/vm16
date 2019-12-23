#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include "../vm16/vm16.h"

#define MEM_SIZE       (2)
#define CYCLES         (1000000)

uint16_t code[] = {
0x1010, 0x1111, 0x1030, 0x2222, 0x1050, 0x3333, 0x1070, 0x4444,
0x7000, 0x2001, 0x2462, 0x2870, 0x0003, 0x2C10, 0x0003, 0x7000,
0x0A00, 0x0023, 0x0000, 0x5A00, 0x0017, 0x4010, 0x0025, 0x7000,
0x5A00, 0x001C, 0x4810, 0x0027, 0x5A00, 0x0020, 0x4C10, 0x0029,
0x7000, 0x1600, 0x002C, 0x1800, 0x0C00, 0x680D, 0x0C00, 0x3C00,
0x0C00, 0x3810, 0xFFFF, 0x0C00, 0x1220, 0x1000, 0x1090, 0x1001,
0x1101, 0x1880, 0x1142, 0x1143, 0x0400
};

uint16_t code2[] = {
0x100C, 0x2410, 0x0014, 0x4C12, 0x0002, 0x2010, 0x0002, 0x4C12,
0x0002, 0x2050, 0x0002, 0x4C12, 0xFFF3, 0x0400
};

int main() {
    clock_t t;
    uint32_t ran;
    int64_t num_cycles;
    uint16_t val;
    uint32_t size = vm16_calc_size(MEM_SIZE);
    vm16_t *C = (vm16_t *)malloc(size);
    vm16_init(C, size);
    vm16_mark_rom_bank(C, 1) ;
    vm16_write_mem(C, 0, sizeof(code) / 2, code);
    vm16_init_mem_banks(C);
    while(vm16_run(C, 1, &ran) != VM16_HALT) {
        printf("A:%04X B:%04X C:%04X D:%04X X:%04X Y:%04X PC:%04X SP:%04X\n", C->areg, C->breg, C->creg, C->dreg, C->xreg, C->yreg, C->pcnt, C->sptr);
        printf("%04X %04X %04X %04X %04X %04X %04X %04X\n", C->memory[0], C->memory[1], C->memory[2], C->memory[3], C->memory[0xFFE], C->memory[0xFFF], C->memory[0x1000], C->memory[0x1001]);
    }

    t = clock();
    vm16_run(C, 500000000, &ran);
    t = clock() - t;
    printf("Performance = %li MIPS\n", ran / t);

    val = 0x2008;
    for(int i=0; i<4096; i++) {
        vm16_write_mem(C, i, 1, &val);
    }
    t = clock();
    vm16_run(C, 500000000, &ran);
    t = clock() - t;
    printf("Performance = %li MIPS\n", ran / t);

    for(int i=0; i<10000; i++) {
        for(int ii=0; ii<4096; ii++) {
            val = (uint16_t)random();
            vm16_write_mem(C, ii, 1, &val);
        }
        num_cycles = 100000;
        while(num_cycles > 0) {
            vm16_run(C, num_cycles, &ran);
            num_cycles = num_cycles - ran;
        }
    }

    vm16_write_mem(C, 0, sizeof(code2) / 2, code2);
    vm16_loadaddr(C, 0);
    while(vm16_run(C, 1, &ran) != VM16_HALT) {
        printf("A:%04X B:%04X C:%04X D:%04X X:%04X Y:%04X PC:%04X SP:%04X\n", C->areg, C->breg, C->creg, C->dreg, C->xreg, C->yreg, C->pcnt, C->sptr);
        printf("%04X %04X %04X %04X %04X %04X %04X %04X\n", C->memory[0], C->memory[1], C->memory[2], C->memory[3], C->memory[0xFFE], C->memory[0xFFF], C->memory[0x1000], C->memory[0x1001]);
    }

    free(C);
    return 0;
}
