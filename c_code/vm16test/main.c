#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include "../vm16/vm16.h"

uint16_t code[] = {
0x2010, 0x1111, 0x2030, 0x2222, 0x2050, 0x3333, 0x2070, 0x4444,
0x3001, 0x3462, 0x3870, 0x0003, 0x3C10, 0x0003, 0x1600, 0x0021,
0x0C00, 0x6A00, 0x0015, 0x5010, 0x0023, 0x0C00, 0x6A00, 0x001A,
0x5810, 0x0025, 0x6A00, 0x001E, 0x5C10, 0x0027, 0x0C00, 0x1200,
0x002A, 0x2800, 0x1800, 0x7C0D, 0x1800, 0x4C00, 0x1800, 0x4810,
0xFFFF, 0x1800, 0x2220, 0x1000, 0x2090, 0x1001, 0x2101, 0x2880,
0x2142, 0x2143, 0x1C00
};

int main() {
    clock_t t;
    uint32_t ran;
    int64_t num_cycles;
    uint16_t val;
    uint32_t size = vm16_calc_size(1);
    vm16_t *C = (vm16_t *)malloc(size);
    vm16_init(C, size);
    //vm16_mark_rom_bank(C, 1) ;
    vm16_write_mem(C, 0, sizeof(code) / 2, code);
    vm16_init_mem_banks(C);
    while(vm16_run(C, 1, &ran) != VM16_HALT) {
        printf("A:%04X B:%04X C:%04X D:%04X X:%04X Y:%04X PC:%04X SP:%04X\n", C->areg, C->breg, C->creg, C->dreg, C->xreg, C->yreg, C->pcnt, C->sptr);
        printf("%04X %04X %04X %04X %04X %04X %04X %04X\n", C->memory[0], C->memory[1], C->memory[2], C->memory[3], C->memory[0xFFE], C->memory[0xFFF], C->memory[0x1000], C->memory[0x1001]);
    }

    val = 0x0C00;
    for(int i=0; i<4096; i++) {
        vm16_poke(C, i, val);
    }
    vm16_loadaddr(C, 0);
    t = clock();
    vm16_run(C, 50000000, &ran);
    t = clock() - t;
    printf("Performance = %li MIPS\n", ran / t);

    val = 0x2010;
    for(int i=0; i<4096; i++) {
        vm16_poke(C, i, val);
    }
    vm16_loadaddr(C, 0);
    t = clock();
    vm16_run(C, 50000000, &ran);
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

    free(C);
    return 0;
}
