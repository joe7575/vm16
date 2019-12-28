# VM16 Lua API

The VM16 virtual machine provides the following API functions.



## create

```
vm = vm16.create(pos, ram_size)
```

Initially create the virtual machine VM13. `ram_size` is a value between 1 (for 4 KWords)  and 16 (for 64 KWords memory).

The function returns the vm instance needed for all further API calls.

## destroy

```
vm16.destroy(vm, pos)
```

Delete the instance and the vm stored as node meta data.

## mark_rom_bank

```
 res = vm16.mark_rom_bank(vm, block_num)
```

Mark the given bank (1..15) as ROM (read only) block
Hint: The bank has to be a valid ram area, initialized via `vm16.create()`.
The function can be called several times for different ROM banks, it returns true/false

## init_mem_banks

To be called after `vm16.mark_rom_bank()` to finalize the memory initialization.
The function returns true/false.

## loadaddr

```
 res = vm16.loadaddr(vm, addr)
```

Load the PC (program counter) of the VM with the given 16-bit address
The function returns true/false.

## deposit

```
res = vm16.deposit(vm, value)
```

Store the given value in the memory cell where the PC points to and post-increment the PC.
The function returns true/false.

## examine

```
res = vm16.examine(vm)
```

Read the memory cell where the PC points to and post-increment the PC.
The function returns true/false.

## read_mem

```
tbl = vm16.read_mem(vm, addr, num)
```

Read a memory block starting at the given `addr` with `num` number of words.
Function returns an table/array with the read values.

## write_mem

```
num = vm16.write_mem(vm, addr, tbl)
```

Write a memory block with values from `tbl` starting at the given `addr`. 
Function returns the number of written values.

## get_cpu_reg

```
tbl = vm16.get_cpu_reg(vm)
```

Return the complete register set as table with the keys `A`, `B`, `C`, `D`, `X`, `Y`, `PC`, `SP`, plus 4 memory cells `mem0` to `mem3` (the PC points to `mem0`)

## testbit

```
res = vm16.testbit(value, bit)
```

Test if the `bit` number (0..15) is set in `value`
Function returns true/false

## call

```
resp, ran = vm16lib.call(vm, pos, cycles, input, output, system)
```

Call the VM to execute the given number of `cycles` (1..n).

The function returns the call response value plus the number of executed run cycles.

The response value is one of:

- `vm16.OK` - the VM terminated after the given number of cycles
- `vm16.DELAY` - the VM terminated with a `dly` instruction
- `vm16.IN`   - the VM terminated with a `in` instruction 
- `vm16.OUT` - the VM terminated with a `out` instruction
- `vm16.SYS` - the VM terminated with a `sys` instruction
- `vm16.HALT` - the VM terminated with a `halt` instruction
- `vm16.ERROR` - the VM terminated because of an internal error

In case of  `IN`, `OUT`, and `SYS` the provided callback function is called, before the function returns.

The callback function are:

- `input`  is a callback of type: `u16_result, points = func(vm, pos, u16_addr)`
- `output` is a callback of type: `u16_result, points = func(vm, pos, u16_addr, u16_value)`
- `system` is a callback of type: 
  `u16_regA, u16_regB, points = func(vm, pos, u16_addr, u16_regA, u16_regB)`

## vm_store

```
vm16.vm_store(vm, pos)
```

Store the complete VM as node meta data, to be restored after e.g. a server restart.

## vm_restore

```
vm = vm16.vm_restore(pos)
```

Restore the complete VM from the node meta data.
The function returns the vm instance.

