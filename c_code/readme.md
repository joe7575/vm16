# VM16

To add the VM code to Minetest:

1. Copy the content of folder `vm16` to `/minetest/src/script/vm16`

   

2. Add two lines to `./minetest/src/script/CMakeLists.txt`

```c
add_subdirectory(vm16)

# Used by server and client
set(common_SCRIPT_SRCS
	...
	${common_SCRIPT_VM16_SRCS}
```



3. Add the following lines to `./minetest/src/script/scripting_server.cpp`:

```c
extern "C" {
#include "lualib.h"
#include "vm16/vm16.h" 				// <== add this line
}
```

and:

```c
ModApiStorage::Initialize(L, top);
ModApiChannels::Initialize(L, top);
luaopen_vm16(L);  						// <== add this line
```

4. Goto the minetest root dir and call `cmake` with all your options

5. call `make`

