# VM16 - 16-bit VM for Minetest mods

The VM16 is a 16-bit virtual machine implemented in C.
It enables simulation of vintage computers in the game Minetest
and is capable of executing real binary code at a remarkable speed.

![screenshot](https://github.com/joe7575/vm16/blob/master/screenshot.png)

Browse on: [GitHub](https://github.com/joe7575/vm16)

Download: [GitHub](https://github.com/joe7575/vm16/archive/master.zip)

Documentation: [GitHub](https://github.com/joe7575/vm16/wiki)


This mod is not very useful on its own, but it can be used as
learning system for VM16 assembler.

See also [PDP-13](https://github.com/joe7575/pdp13).

This mod has two parts:

- C files to be compiled and installed as LuaRocks package
- Lua files to be used as Minetest mod containing the VM16 computer blocks


## Installation

Download the mod from [GitHub](https://github.com/joe7575/vm16/archive/master.zip),
extract the file from the ZIP archive and copy the folder `vm16-master`
into your Minetest `mods` folder.

Change your directory  to `mods/vm16-master` and install the Lua library with:

```
luarocks make
```

For Linux like systems, use:

```
sudo luarocks make
```

The program output should look like this:

```
vm16 2.x-y depends on lua 5.1 (5.1-1 provided by VM)
gcc -O2 -fPIC -I/usr/include/lua5.1 -c src/vm16core.c -o src/vm16core.o
gcc -O2 -fPIC -I/usr/include/lua5.1 -c src/vm16lua.c -o src/vm16lua.o
gcc -shared -o vm16lib.so src/vm16core.o src/vm16lua.o
vm16 2.x-y is now installed in /usr/local (license: GPLv3)
```

For the installation of 'luarocks' (if not already available), see [luarocks](https://luarocks.org/)



To enable this `unsafe` package, add 'vm16' to the list of trusted mods in minetest.conf:

```
secure.trusted_mods = vm16
```


## Configuration

Open the tab Settings -> All Settings -> Mods -> vm16
to enable the CPU/demo blocks or check settingtypes.txt.


## Dependencies

optional: default, basic_materials (for demo CPU and blocks)



## License

Copyright (C) 2019-2022 Joachim Stolberg
Licensed under the GNU GPLv3 (See LICENSE.txt)



## History

### API v3.2/Core v2.6.4/asm v2.2 (2022-03-09)

- Core: Add BP register and [X+n], [Y+1] opernand types
- ASM: Adapt assembler for the new instructions
- Doc: Adapt manuals for the new instructions

### API v3.1/Core v2.6.2 (2022-03-07)

- Add BLL compiler prototype (B like language),
  is unused so far
- ASM: Add support for namespaces (for macro ASM)
- ASM: Allow 3-word instructions (needed by BLL)
- Core: Fix bug in branch instructions

### API v3.0/Core v2.6.1 (2022-02-26)

- Core: Change memory size calculation
- Rework the I/O API and blocks
- Docu: Update vm16_api.md

### v2.6 (2022-02-25)

- Core: Change BRK instruction
- API: Add breakpoint functionality
- CPU: Add breakpoint functionality


### v2.5 (2022-02-22)

- C-core: Add REL2 addressing mode (as replacement for wrong REL implementation)
- Asm: Fix RIP addressing bug (reported by DS)
- Asm: Add 'namespace' and 'global' keyword to enable local and global labels
- Docu: Updates



### Older Versions

- 2022-02-19  v2.4  * Allow 0 for memory size (= 512 words), add computer demo blocks
- 2021-08-30  v2.3  * Improve documentation
- 2021-01-07  v2.3  * Update testing modes
- 2020-12-31  v2.3  * Change vm16_read_h16() parameters
- 2020-12-29  v2.2  * Add breakpoints and read/write_bin functions
- 2020-12-25  v2.1  * Add function 'set_cpu_reg'
- 2020-12-02  v2.0  * Switch to mod storage for VMs
- 2020-11-30  v1.3  * Add functions read_h16/write_h16
- 2020-11-29  v1.2  * Complete rework, Add test nodes
- 2020-11-21  v1.1  * First commit as LuaRocks project

