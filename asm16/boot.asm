; Boot Loader v1.0
;
; Deposite the code at address 0x0F00

        .code

START:  move    x, #0           ; code start address

LOOP:   in      A, #0           ; read status from input #0
        bze     A, +LOOP        ; No data => try again
        in      A, #1           ; read data from input #1
        move    [X]+, A         ; move data to memory via X
        jump    +LOOP           ; repeat
        
