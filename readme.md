# VM16 - 16-bit VM for Minetest mods

The VM16 is a 16-bit virtual machine implemented in C. It enables simulation of vintage computers in the game Minetest and is capable of executing real binary code at a remarkable speed.

Browse on: [GitHub](https://github.com/joe7575/vm16)

Download: [GitHub](https://github.com/joe7575/vm16/archive/master.zip)

This mod is not useful on its own. Only a few test nodes are supplied to test and demonstrate the functions.

See also [vm16asm](https://github.com/joe7575/vm16asm) and [PDP-13](https://github.com/joe7575/pdp13).

This mod has two parts:

- C files to be compiled and installed as LuaRocks package
- Lua files to be used as Minetest mod


## Installation

Download the mod from [GitHub](https://github.com/joe7575/vm16/archive/master.zip), extract the file from the ZIP archive and copy the folder `vm16-master` into your Minetest `mods` folder.

Change your directory  to `mods/vm16-master` and install the Lua library with:

```
luarocks make
```

For Linux like systems, use:

```
sudo luarocks make
```

The program output should like like this:

```
vm16 2.3-0 depends on lua 5.1 (5.1-1 provided by VM)
gcc -O2 -fPIC -I/usr/include/lua5.1 -c src/vm16core.c -o src/vm16core.o
gcc -O2 -fPIC -I/usr/include/lua5.1 -c src/vm16lua.c -o src/vm16lua.o
gcc -shared -o vm16lib.so src/vm16core.o src/vm16lua.o
vm16 2.3-0 is now installed in /usr/local (license: GPLv3)
```

For the installation of 'luarocks' (if not already available), see [luarocks](https://luarocks.org/)



To enable this `unsafe` package, add 'vm16' to the list of trusted mods in minetest.conf:

```
secure.trusted_mods = vm16
```



## Dependencies

none



## License

Copyright (C) 2019-2021 Joachim Stolberg  
Licensed under the GNU GPLv3   (See LICENSE.txt)



## History

- 2020-11-21  v1.1  * First commit as LuaRocks project
- 2020-11-29  v1.2  * Complete rework, Add test nodes
- 2020-11-30  v1.3  * Add functions read_h16/write_h16
- 2020-12-02  v2.0  * Switch to mod storage for VMs
- 2020-12-25  v2.1  * Add function 'set_cpu_reg'
- 2020-12-29  v2.2  * Add breakpoints and read/write_bin functions
- 2020-12-31  v2.3  * Change vm16_read_h16() parameters
- 2001-01-07  v2.3  * Update testing modes



