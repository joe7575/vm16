--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	Progamming example and library function files
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
var str = "Hello world!";


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

Files.stdio_asm = [[
;===================================
; Standard I/O v1.0
; - putchar(c)
; - putstr(s)
; - putnum(val)  -- decimal output
; - puthex(val)  -- hexadecimal output
;===================================

global putchar
global putstr
global putnum
global puthex

  .code

;===================================
; [01] putchar(c)
; c: [SP+1]
;===================================
putchar:
  move A, [SP+1]
  out  #0, A
  ret

;===================================
; [02] putstr(s)
; s: [SP+1]
;===================================
putstr:
  move X, [SP+1]
  move A, #80  ; max string size

loop02:
  move B, [X]
  bze  B, exit02
  dec  A
  bze  A, exit02

  out #0, B
  inc X
  jump loop02

exit02:
  ret

;===================================
; [03] putnum(val)
; val: [SP+1]
;===================================
putnum:
  move A, [SP+1]
  push #0        ; end-of-string

loop03:
  move B, A
  div  B, #10    ; rest in B
  move C, A
  mod  C, #10    ; digit in C
  add  C, #48
  push C         ; store on stack
  move A, B
  bnze A, loop03 ; next digit

output03:
  pop  B
  bze  B, exit03
  out  #0, B
  jump output03

exit03:
  ret

;===================================
; [04] puthex(val)
; val: [SP+1]
;===================================
puthex:
  move A, [SP+1]
  push #0        ; end-of-string
  move C, #4     ; num digits

loop04:
  move B, A
  div  B, #$10   ; rest in B
  mod  A, #$10   ; digit in C
  sklt A, #10    ; C < 10 => jmp +2
  add  A, #7     ; A-F offset
  add  A, #48    ; 0-9 offset
  push A         ; store on stack
  move A, B
  dbnz C, loop04 ; next digit

output04:
  pop  B
  bze  B, exit04
  out  #0, B
  jump output04

exit04:
  ret
]]

Files.mem_asm = [[
;===================================
; Memory v1.0
; - memcpy(dst, src, num)
;===================================

global memcpy

  .code

;===================================
; [01] memcpy(dst, src, num)
; dst: [SP+3]
; src: [SP+2]
; num: [SP+1]
;===================================
memcpy:
  move X, [SP+3]
  move Y, [SP+2]
  move A, [SP+1]

  skgt A, #0
  jump return

loop01:
  move [X]+, [Y]+
  dbnz A, loop01

return:
  ret
]]

return Files
