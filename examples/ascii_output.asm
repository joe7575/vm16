; ASCII output example

move A, #$41   ; load A with 'A'

loop:
  out #00, A   ; output char
  add  A, #01  ; increment char
  jump loop
