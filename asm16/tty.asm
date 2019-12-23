; Read and send chars from/to Telewriter
; Start address is on address 0x0100
; TTY IN  buffer is a address 0000 (64 bytes)
; TTY OUT buffer is a address 0040 (64 bytes)

        .code

START:  move    A,#0
        sys     #0                  ; read TTY on port 0
        bze     A, +START           ; rx char num == 0: repeat

        move    X, #0               ; output buffer again
LOOP:   out     #0, [X]+    
        dbnz    A, +LOOP
        
        out     #0,#10              ; line feed
        
        jump    +START
