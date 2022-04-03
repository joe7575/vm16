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
