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
; stdio v1.0
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
  sys  #0
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

  move A, B
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
; string v1.1
; - strcpy(dst, src)
; - strlen(s)
; - strcmp(str1, str2)
;===================================

global strcpy
global strlen
global strcmp

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
]]

-------------------------------------------------------------------------------
-- math.asm
-------------------------------------------------------------------------------
vm16.libc.math_asm = [[
;===================================
; math v1.0
; - min(a, b)
; - max(a, b)
;===================================

global min
global max

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

]]

