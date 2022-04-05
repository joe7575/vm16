--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	Standard library functions
]]--

local Files = {}

-------------------------------------------------------------------------------
-- stdio.asm
-------------------------------------------------------------------------------
Files.stdio_asm = [[
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

-------------------------------------------------------------------------------
-- mem.asm
-------------------------------------------------------------------------------
Files.mem_asm = [[
;===================================
; mem v1.0
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

-------------------------------------------------------------------------------
-- string.asm
-------------------------------------------------------------------------------
Files.string_asm = [[
;===================================
; [20] string v1.0
; - strcpy(dst, src)
; - strlen(s)
;===================================

global strcpy
global strlen

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

]]

-------------------------------------------------------------------------------
-- math.asm
-------------------------------------------------------------------------------
Files.math_asm = [[
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
  ret  [SP+1]
  nop
  ret  [SP+2]

;===================================
; [01] min(a, b)
; a: [SP+2]
; b: [SP+1]
;===================================
min:
  skgt [SP+2], [SP+1]
  ret  [SP+2]
  nop
  ret  [SP+1]

]]

return Files
