; Punch a memory block to tape (Telewriter v1.0)
; Start address is on address 0x0FF0
; Size in words on address 0x0FF1

        .code

START:  move    X, #$0FF0
        move    B, #$0FF1

LOOP:   out     #0, [X]+    
        dbnz    B, +LOOP
        halt

