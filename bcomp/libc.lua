--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	Standard library functions
]]--

vm16.libc = {}

-------------------------------------------------------------------------------
-- stdio.asm
-------------------------------------------------------------------------------
vm16.libc.stdio_asm = [[
;===================================
; stdio v1.2
; - setstdout(val) -- 1 for terminal
; - putchar(c)
; - putstr(s)
; - putnum(val)  -- decimal output
; - puthex(val)  -- hexadecimal output
; - putnumf(val) -- dec. output with leading zeros
; - getchar()
;===================================

global setstdout
global putchar
global putstr
global putnum
global puthex
global putnumf
global getchar

  .code

;===================================
; [01] putchar(c)
; c: [SP+1]
;===================================
putchar:
  move A, [SP+1]
  sys  #0
  ret

;===================================
; [02] putstr(s)
; s: [SP+1]
;===================================
putstr:
  move X, [SP+1]
  move C, #80  ; max string size

loop02:
  move A, [X]
  bze  A, exit02
  dec  C
  bze  C, exit02

  sys #0
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
  move A, B
  sys  #0
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
  move A, B
  sys  #0
  jump output04

exit04:
  ret

;===================================
; [05] setstdout(val)
; val: [SP+1]
;===================================
setstdout:
  move A, [SP+1]
  sys  #1
  ret

;===================================
; [06] putnumf(val)
; val: [SP+1]
;===================================
putnumf:
  move A, [SP+1]
  push #0        ; end-of-string
  move C, #5     ; num digits

loop06:
  move B, A
  div  B, #10    ; rest in B
  mod  A, #10    ; digit in C
  add  A, #48    ; 0-9 offset
  push A         ; store on stack
  move A, B
  dbnz C, loop06 ; next digit

output06:
  pop  B
  bze  B, exit06
  move A, B
  sys  #0
  jump output06

exit06:
  ret

;===================================
; [07] getchar()
;===================================
getchar:
  sys  #2
  ret
]]

-------------------------------------------------------------------------------
-- mem.asm
-------------------------------------------------------------------------------
vm16.libc.mem_asm = [[
;===================================
; mem v1.0
; - memcpy(dst, src, num)
; - memcmp(ptr1, ptr2, num)
; - memset(ptr, val, num)
;===================================

global memcpy
global memcmp
global memset

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
  jump exit01

loop01:
  move [X]+, [Y]+
  dbnz A, loop01

exit01:
  ret

;===================================
; [02] memcmp(ptr1, ptr2, num)
; ptr1: [SP+3]
; ptr2: [SP+2]
; num:  [SP+1]
;===================================
memcmp:
  move X, [SP+3]
  move Y, [SP+2]
  move A, [SP+1]

  skgt A, #0
  jump exit02

loop02:
  skne [X]+, [Y]+
  dbnz A, loop02

  dec X
  dec Y

exit02:
  move A, [X]
  sub  A, [Y]
  ret

;===================================
; [03] memset(ptr, val, num)
; ptr:  [SP+3]
; val:  [SP+2]
; num:  [SP+1]
;===================================
memset:
  move X, [SP+3]
  move B, [SP+2]
  move A, [SP+1]

  skgt A, #0
  jump exit03

loop03:
  move [X]+, B
  dbnz A, loop03

exit03:
    ret
]]

-------------------------------------------------------------------------------
-- string.asm
-------------------------------------------------------------------------------
vm16.libc.string_asm = [[
;===================================
; string v1.2
; - strcpy(dst, src)
; - strlen(s)
; - strcmp(str1, str2)
; - strcat(dst, src)
; - strpack(str)
;===================================

global strcpy
global strlen
global strcmp
global strcat
global strpack

  .code

;===================================
; [01] strcpy(dst, src)
; dst: [SP+2]
; src: [SP+1]
;===================================
strcpy:
  move X, [SP+2]
  move Y, [SP+1]
  move A, X

loop01:
  move [X]+, [Y]
  bnze [Y]+, loop01

  ret

;===================================
; [02] strlen(str)
; str: [SP+1]
;===================================
strlen:
  move X, [SP+1]
  move A, #0

loop02:
  move B, [X]+
  inc  A
  bnze [X], loop02

  ret

;===================================
; [03] strcmp(str1, str2)
; str1: [SP+2]
; str2: [SP+1]
; returns 0 if equal
;===================================
strcmp:
  move X, [SP+2]
  move Y, [SP+1]
  move A, X

loop03:
    bze   [X], exit03
    skne  [X]+, [Y]+
    jump  loop03

    dec X
    dec Y

exit03:
    move A, [X]
    sub  A, [Y]
    ret

;===================================
; [04] strcat(dst, src)
; dst: [SP+2]
; src: [SP+1]
;===================================
strcat:
  move X, [SP+2]

loop04:
  move A, [X]+
  bnze [X], loop04

  move [SP+2], X
  jump strcpy

;===================================
; [05] strpack(str)
; str: [SP+1]
;===================================
strpack:
  move X, [SP+1]
  move Y, [SP+1]
  move B, #0
loop05:
  move A, [X]+
  bnze A, elseif ; if A == 0 then
  bnze B, else1  ;     if B == 0 then
  move [Y]+, A
  jump exit05
else1:           ;     else
  move [Y]+, B
  move [Y]+, A
  jump exit05
elseif:          ;     end
  sklt A, #256   ; elseif A < 256 then
  jump else2
  bnze B, else3  ;     if B == 0 then
  move B, A
  jump loop05
else3:           ;     else
  shl  B, #8
  add  B, A
  move [Y]+, B
  move B, #0
  jump loop05    ;     end
else2:           ; else // A > 255
  bnze B, else4  ;     if B == 0 then
  move [Y]+, A
  jump loop05
else4:           ;     else
  shl  B, #8
  move D, A
  shr  D, #8
  add  B, D
  move [Y]+, B
  and  A, #255
  move B, A
  jump loop05    ;     end
                 ; end
exit05:
  move A, [SP+2]
  ret
]]

-------------------------------------------------------------------------------
-- math.asm
-------------------------------------------------------------------------------
vm16.libc.math_asm = [[
;===================================
; math v1.1
; - min(a, b)
; - max(a, b)
; - abs(a)
;===================================

global min
global max
global abs

  .code

;===================================
; [01] min(a, b)
; a: [SP+2]
; b: [SP+1]
;===================================
min:
  skgt [SP+2], [SP+1]
  jump else01
  move A, [SP+1]
  ret

else01:
  move A, [SP+2]
  ret

;===================================
; [02] max(a, b)
; a: [SP+2]
; b: [SP+1]
;===================================
max:
  skgt [SP+2], [SP+1]
  jump else02
  move A, [SP+2]
  ret

else02:
  move A, [SP+1]
  ret

;===================================
; [03] abs(a)
; a: [SP+1]
;===================================
abs:
  bpos [SP+1], exit03
  not  [SP+1]
  inc  [SP+1]

exit03:
  move A, [SP+1]
  ret

]]

-------------------------------------------------------------------------------
-- stdlib.asm
-------------------------------------------------------------------------------
vm16.libc.stdlib_asm = [[
;===================================
; stdlib v1.0
; - itoa(val, str)
; - itoha(val, str)
; - halt()
;===================================

global itoa
global itoha
global halt

  .code

;===================================
; [01] itoa(val, str)
; val: [SP+2]
; str: [SP+1]
;===================================
itoa:
  move A, [SP+2]
  move X, [SP+1]
  move D, X      ; return val
  push #0        ; end-of-string

loop01:
  move B, A
  div  B, #10    ; rest in B
  move C, A
  mod  C, #10    ; digit in C
  add  C, #48
  push C         ; store on stack
  move A, B
  bnze A, loop01 ; next digit

output01:
  pop  A
  bnze A, getB01

  ; A is 0
  move [X], A
  jump exit01

getB01:
  pop  B
  bnze B, merge01

  ; B is 0
  move [X]+, A
  move [X], B
  jump exit01

merge01:
  shl  A, #8
  add  A, B
  move [X]+, A
  jump output01

exit01:
  move A, D
  ret

;===================================
; [02] itoha(val, str)
; val: [SP+2]
; str: [SP+1]
;===================================
itoha:
  move A, [SP+2]
  move X, [SP+1]
  move D, X      ; return val
  move C, #4     ; num digits

loop02:
  move B, A
  div  B, #$10   ; rest in B
  mod  A, #$10   ; digit in C
  sklt A, #10    ; C < 10 => jmp +2
  add  A, #7     ; A-F offset
  add  A, #48    ; 0-9 offset
  push A         ; store on stack
  move A, B
  dbnz C, loop02 ; next digit

output02:
  pop  A
  shl  A, #8
  pop  B
  add  A, B
  move [X]+, A

  pop  A
  shl  A, #8
  pop  B
  add  A, B
  move [X]+, A

  move [X], #0

  move A, D
  ret

;===================================
; [03] halt()
;===================================
halt:
  halt
]]

