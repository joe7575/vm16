INP_CNTR = $3E      ; char counter
OUT_CNTR = $3F      ; char counter
INP_BUFF = $40      ; RX buffer (64 chars)
OUT_BUFF = $80      ; TX buffer (64 chars)
TTY_ADDR = #0       ; I/O addr (port-num * 8)

        .org $200
        .code

        jump 0
START3:  move    X, #TEXT            ; source address
        move    Y, #OUT_BUFF        ; destination address

loop:   move    [Y]+, [X]
        bnze    [X]+, +loop

        sub     Y, #OUT_BUFF        ; calc string size
        move    OUT_CNTR, Y         ; store string size

        move    A, #1               ; TTY output
        move    B, TTY_ADDR         ; I/O port
        sys     0
        
        halt

        .text
       
TEXT:   "Hello "
        "World 2!\n\0"  ; \n is needed for the Telewriter, \0 as end mark for the loop

        .btext
       
TEXT2:  "Hello "
        "World 2!\n\0"  ; \n is needed for the Telewriter, \0 as end mark for the loop

        .data
DATA:   $10,$1234,4000   ,    0        

        .code
exit:   move $1000, A
        move X, #$1001
        move [X], B
        inc   X
        move [X]+, C
        move [X]+, D
        halt
        jump 0
        jump #0
        jump $0
        jump #$0
