# VM16 - 16-bit VM for Minetest mods

The VM16 is a 16-bit virtual machine implemented in C. It enables simulation of vintage computers in the game Minetest and is capable of executing real binary code at a remarkable speed.

Browse on: [GitHub](https://github.com/joe7575/vm16)

Download: [GitHub](https://github.com/joe7575/vm16/archive/master.zip)

This mod is not useful on its own. Only a few test nodes are supplied to test and demonstrate the functions.

This mod has two parts:

- C files to be compiled and installed as LuaRocks package
- Lua files to be used as Minetest mod
- 

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
vm16 1.1-1 depends on lua 5.1 (5.1-1 provided by VM)
gcc -O2 -fPIC -I/usr/include/lua5.1 -c src/vm16core.c -o src/vm16core.o
gcc -O2 -fPIC -I/usr/include/lua5.1 -c src/vm16lua.c -o src/vm16lua.o
gcc -shared -o vm16lib.so src/vm16core.o src/vm16lua.o
vm16 1.1-1 is now installed in /usr/local (license: GPLv3) 
```

For the installation of 'luarocks' (if not already available), see [luarocks](https://luarocks.org/)



To enable this `unsafe` package, add 'vm16' to the list of trusted mods in minetest.conf:

```
secure.trusted_mods = vm16
```



## Dependencies

none



## License

Copyright (C) 2019-2020 Joachim Stolberg  
Licensed under the GNU GPLv3   (See LICENSE.txt)



## History

- 2020-11-21  v1.1  * First commit as LuaRocks project
- 2020-11-29  v1.2  * Complete rework, Add test nodes
- 2020-11-30  v1.3  * Add functions read_h16/write_h16



