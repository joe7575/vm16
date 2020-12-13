# VM16 Lua API

The VM16 virtual machine provides the following API functions.



## create

```LUA
vm = vm16.create(pos, ram_size)
```

Initially create the virtual machine VM13. Valid values for `ram_size` are:

- 1 for 4 KWords memory
- 2 for 8 KWords memory
- 4 for 16 KWords memory
- 8 for 32 KWords memory
- 16 for 64 KWords memory

The function returns true/false.

## destroy

```LUA
vm16.destroy(pos)
```

Delete the instance and the stored VM data.

## is_loaded

```lua
vm16.is_loaded(pos)
```

Return true if VM is loaded, otherwise false.

## vm_restore

```LUA
vm16.vm_restore(pos)
```

Move stored VM back to active. Typically called from the node LBM function.

## mem_size

```LUA
vm16.mem_size(pos)
```

Returns the VM memory size in words.

## set_pc

```LUA
 res = vm16.set_pc(pos, addr)
```

Load the PC (program counter) of the VM with the given 16-bit address.
The function returns true/false.

## get_pc

```LUA
 addr = vm16.get_pc(pos)
```

Return the current PC value.

## deposit

```
res = vm16.deposit(pos, value)
```

Store the given value in the memory cell where the PC points to and post-increment the PC. The function returns true/false.

## read_mem

```LUA
tbl = vm16.read_mem(pos, addr, num)
```

Read a memory block starting at the given `addr` with `num` number of words.
Function returns an table/array with the read values.

## write_mem

```LUA
num = vm16.write_mem(pos, addr, tbl)
```

Write a memory block with values from `tbl` starting at the given `addr`. 
Function returns the number of written values.

## read_ascii

```LUA
s = vm16.read_ascii(pos, addr, num)
```

Read a memory block starting at the given `addr` and return the
data as ASCII string with up to `num` characters.

## peek

```LUA
val = vm16.peek(pos, addr)
```

Peek and return the memory cell at `addr`.

## poke

```LUA
res = vm16.poke(pos, addr, value)
```

Write a value to the given `addr`.  Function returns true/false.

## get_cpu_reg

```
tbl = vm16.get_cpu_reg(pos)
```

Return the complete register set as table with the keys `A`, `B`, `C`, `D`, `X`, `Y`, `PC`, `SP`, plus 2 memory cells `mem0` and `mem1` (the PC points to `mem0`)

## get_io_reg

```
tbl = vm16.get_cpu_reg(pos)
```

Return a reduced register set as table with the keys `A`, `B`, `addr` and `data` , nedded for input/output operations.

## set_io_reg

```
tbl = vm16.get_cpu_reg(pos, io)
```

Store the values from the given io table (keys: `A`, `B`, `addr` and `data`)

## write_h16

```LUA
res = vm16.write_h16(pos, s)
```

Write a H16 file (generated by the assembler) into VM memory.
Function returns true/false

## read_h16

```LUA
res = vm16.read_h16(pos)
```

Read all memory areas which are not equal to zero and return the data as H16 string. This is used to save program code e. g. to tape. 
Function returns true/false.

## testbit

```LUA
res = vm16.testbit(value, bit)
```

Test if the `bit` number (0..15) is set in `value`
Function returns true/false

## run

```LUA
resp, ran = vm16.run(pos, cycles)
```

Call the VM to execute the given number of `cycles` (1..n).

The response value is one of:

- `vm16.OK` - the VM terminated after the given number of cycles (or slot time expired)
- `vm16.HALT` - the VM terminated with a `halt` instruction
- `vm16.ERROR` - the VM terminated because of an internal error
