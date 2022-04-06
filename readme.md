# VM16 - 16-bit VM for Minetest mods

The VM16 is a 16-bit virtual machine and a development environment with
compiler, assembler and debugger.

It enables simulation of computers in the game Minetest and is capable of
executing real binary code at a remarkable speed.

**The mod is currently under construction. Not all files and documents are always updated !!!**

![screenshot](https://github.com/joe7575/vm16/blob/master/screenshot.png)

Browse on: [GitHub](https://github.com/joe7575/vm16)

Download: [GitHub](https://github.com/joe7575/vm16/archive/master.zip)

Documentation: [GitHub](https://github.com/joe7575/vm16/wiki)

This mod is not very useful on its own. The real purpose for VM16 is to provide
a programming environment to be easily integrated into other mods.

This mod consists of several parts:

- C files to be compiled and installed as LuaRocks package (the core VM)
- Lua files as API to the VM (low level interface)
- Programmer and server blocks as development environment to be used to be used
  by other Minetest mods (high level interface)
- Some demo blocks showing the usage of programmer and server. These blocks have
  to be enabled via `vm16_testblocks_enabled` (see `settingtypes.txt`)


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

For the installation of 'luarocks' (if not already available),
see [luarocks](https://luarocks.org/)



To enable this `unsafe` package, add 'vm16' to the list of trusted mods in minetest.conf:

```
secure.trusted_mods = vm16
```


## Configuration

Open the tab Settings -> All Settings -> Mods -> vm16
to enable the CPU/demo blocks or check settingtypes.txt.

## Demo blocks

The vm16 mod comes with the programmer, the file server, a computer, a lamp,
and a switch block for training purposes.
It can be used to get familiar with the programming environment.


## First Steps

- Craft the 5 blocks "VM16 Programmer", "VM16 File Server", "VM16 Demo Computer",
  VM16 On/Off Switch" and "VM16 Color Lamp".
- Place "VM16 Demo Computer", VM16 On/Off Switch" and "VM16 Color Lamp" next to each other.
  The computer searches for I/O blocks in an area with a radius of 3 blocks.
- The switch is used as input block for the computer, the lamp as output block.
- Give lamp and switch an I/O address. For the provided example, address '1' is used for both blocks.
- You can add further I/O blocks for you own programs with other addresses.
- Place the server anywhere.
- Connect the programmer with server and CPU by left-clicking with the wielded
  programmer on server and CPU block.
- Place the programmer anywhere.
- Press the "Init" button to initialize the computer.
- Now double-click on the file "example1.c" to open the edit.
- Click on "Debug" to start the debugger.
- Click on "Run" to execute the program. The lamp block should now change its color

## Dependencies

None.
Optional: default, basic_materials (for demo CPU and blocks)


## License

Copyright (C) 2019-2022 Joachim Stolberg
Licensed under the GNU GPLv3 (See LICENSE.txt)



## ToDo

- Improve compiler (switch/case, functional blocks, ...)
- Bug fixes
- Adapt manuals
- Add compiler manual
- ...



## History

### API v3.3/Core v2.6.5/asm v2.3/Compiler v1.2 (2022-04-03)

**Work in progress!**

- Simplify and standardize compiler and assembler output
- Enable import of C and ASM files in C files
- Update and improve debugger (add step-in and step-out buttons)
- Add more example code to the demo CPU
- Many improvements and bug fixes

### API v3.3/Core v2.6.5/asm v2.2/Compiler v1.1 (2022-03-26)

**Work in progress!**

- Expand compiler with arrays and pointers
- Expand compiler with strings and chars
- Expand compiler with constants and inline assembler
- Update debugger
- Bug fixes

### API v3.3/Core v2.6.5/asm v2.2 (2022-03-19)

**Work in progress!**

- Core: Add TOS register for the debugger
- Add VM16 Programmer and VM16 File Server
- Programmer provides compiler, debugger, and variable watch window

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

