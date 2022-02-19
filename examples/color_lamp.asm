; VM16 Color lamp demo v1.0
; Color Lamp on output port #1
; On/Off Switch on input port #1

  move A, #00  ; color value in A

loop:
  nop          ; 100 ms delay
  in   B, #1   ; read switch value
  bze  B, loop
  and  A, #$3F ; values from 1 to 64
  add  A, #01
  out  #01, A  ; output color value
  jump loop
