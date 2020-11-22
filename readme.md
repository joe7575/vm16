# VM16 - 16-bit VM for Minetest mods

The VM16 is a 16-bit virtual machine implemented in C. It enables simulation of vintage computers in the game Minetest and is capable of executing real binary code at a remarkable speed.

Browse on: ![GitHub](https://github.com/joe7575/vm16)

Download: ![GitHub](https://github.com/joe7575/vm16/archive/master.zip)



## Installation

```
luarocks install vm16
```

To enable this `unsafe` package, add 'vm16' to the list of trusted mods in minetest.conf:

```
secure.trusted_mods = vm16
```

For the installation of 'luarocks' (if not already available), see [luarocks](https://luarocks.org/)



## API Functions

### create

```LUA
vm = vm16.create(pos, ram_size)
```

Initially create the virtual machine VM13. `ram_size` is a value between 1 (for 4 KWords)  and 16 (for 64 KWords memory).

The function returns the vm instance needed for all further API calls.

### destroy

```LUA
vm16.destroy(vm, pos)
```

Delete the instance and the vm stored as node meta data.

### loadaddr

```LUA
 res = vm16.loadaddr(vm, addr)
```

Load the PC (program counter) of the VM with the given 16-bit address
The function returns true/false.

### deposit

```
res = vm16.deposit(vm, value)
```

Store the given value in the memory cell where the PC points to and post-increment the PC.
The function returns true/false.

### examine

```LUA
res = vm16.examine(vm)
```

Read the memory cell where the PC points to and post-increment the PC.
The function returns true/false.

### read_mem

```LUA
tbl = vm16.read_mem(vm, addr, num)
```

Read a memory block starting at the given `addr` with `num` number of words.
Function returns an table/array with the read values.

### write_mem

```LUA
num = vm16.write_mem(vm, addr, tbl)
```

Write a memory block with values from `tbl` starting at the given `addr`. 
Function returns the number of written values.

### get_cpu_reg

```
tbl = vm16.get_cpu_reg(vm)
```

Return the complete register set as table with the keys `A`, `B`, `C`, `D`, `X`, `Y`, `PC`, `SP`, plus 4 memory cells `mem0` to `mem3` (the PC points to `mem0`)

### testbit

```LUA
res = vm16.testbit(value, bit)
```

Test if the `bit` number (0..15) is set in `value`
Function returns true/false

### call

```LUA
resp, ran = vm16.call(vm, pos, cycles, input, output, system)
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

### vm_store

```LUA
vm16.vm_store(vm, pos)
```

Store the complete VM as node meta data, to be restored after e.g. a server restart.

### vm_restore

```LUA
vm = vm16.vm_restore(pos)
```

Restore the complete VM from the node meta data.
The function returns the vm instance.



## Dependencies

none



## License

Copyright (C) 2019-2020 Joachim Stolberg  
Licensed under the GNU GPLv3   (See LICENSE.txt)



## History

- 2020-11-21  v1.1  * First commit as LuaRocks project



