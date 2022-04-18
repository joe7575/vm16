--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	Progamming examples
]]--

-- Examples will be added to the programmer file system as read-only files.
Example1_asm = [[
; Read button on input #1 and
; control demo lamp on output #1.

  move A, #00  ; color value in A

loop:
  nop          ; 100 ms delay
  nop          ; 100 ms delay
  in   B, #1   ; read switch value
  bze  B, loop
  and  A, #$3F ; values from 1 to 64
  add  A, #01
  out  #01, A  ; output color value
  jump loop
]]

Example1_c = [[
// Read button on input #1 and
// control demo lamp on output #1.

func main() {
  var idx = 0;

  while(1){
    if(input(1) == 1) {
      output(1, idx);
      idx = (idx + 1) % 64;
    } else {
      output(1, 0);
    }
    sleep(2);
  }
}
]]

Example2_c = [[
// Output some characters on the
// programmer status line (system #0).

var max = 32;

func get_char(i) {
  return 0x40 + i;
}

func main() {
  var i;

  for(i = 0; i < max; i++) {
    system(0, get_char(i));
  }
  return;  
}
]]

-- Will be added to the programmer file system as read-only C-file.
Example3_c = [[
// Example with inline assembler

func main() {
  var idx = 0;

  while(1){
    if(input(1) == 1) {
      output(1, idx);
      //idx = (idx + 1) % 64;
      _asm_{
        add [SP+0], #1
        mod [SP+0], #64
      }
    } else {
      output(1, 0);
    }
    sleep(2);
  }
}

]]

Example4_c = [[
// Show the use of library functions

import "stdio.asm"
import "mem.asm"

var arr1[4] = {1, 2, 3, 4};
var arr2[4];
var str[] = "Hello world!";


func main() {
  var i;

  memcpy(arr2, arr1, 4);
  for(i = 0; i < 4; i++) {
    putnum(arr2[i]);
  }

  putchar('  ');
  putstr(str);
  putchar('  ');
  puthex(0x321);

  return;
}
]]

vm16.register_ro_file("vm16", "example1.c",   Example1_c)
vm16.register_ro_file("vm16", "example2.c",   Example2_c)
vm16.register_ro_file("vm16", "example3.c",   Example3_c)
vm16.register_ro_file("vm16", "example4.c",   Example4_c)
vm16.register_ro_file("vm16", "example1.asm", Example1_asm)

vm16.register_ro_file("vm16", "stdio.asm",  vm16.libc.stdio_asm)
vm16.register_ro_file("vm16", "mem.asm",    vm16.libc.mem_asm)
vm16.register_ro_file("vm16", "string.asm", vm16.libc.string_asm)
vm16.register_ro_file("vm16", "math.asm",   vm16.libc.math_asm)
