--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	Progamming examples
]]--

local Files = {}

-- Examples will be added to the programmer file system as read-only files.
Files.example1_asm = [[
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

Files.example1_c = [[
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

Files.example2_c = [[
// Output some characters on the
// programmer status line (output #0).

var max = 32;

func get_char(i) {
  return 0x40 + i;
}

func main() {
  var i;

  for(i = 0; i < max; i++) {
    output(0, get_char(i));
  }
}
]]

-- Will be added to the programmer file system as read-only C-file.
Files.example3_c = [[
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

Files.example4_c = [[
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

return Files
