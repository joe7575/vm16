;===================================
; String library v1.0
; - strcpy(dst, src, nmax)
; - strcat(dst, src, nmax)
; - strset(dst, val, nmax)
; - putstr(s)
; - putchar(c)
; - putnum(val, base)
;===================================

global strcpy
global strcat
global strset
global putstr
global putchar
global putnum

;===================================
; putstr [01]
;===================================
putstr:
  push #0
;  27:   while(s[i] != 0) {
loop01:
  move A, [SP+2]
  add A, [SP+0]
  move X, A
  move B, [X]
  skne B, #0
  jump lbl7
;  28:     output(0, s[i]);
  move A, [SP+2]
  add A, [SP+0]
  move X, A
  out #0, [X]
;  29:     i++;
  inc [SP+0]
  jump lbl6
lbl7:
;  30:   }
  add SP, #1
  ret
