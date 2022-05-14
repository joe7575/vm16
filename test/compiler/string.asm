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
