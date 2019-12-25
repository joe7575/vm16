; Hello world for the Telewriter v1.0
;

        .code

$include "itoa.asm"

START:  move    X, #TEXT

LOOP:   out     #0, [X]    
        bnze    [X]+, +LOOP

        inc     $100

        move    A,$100              ; 1000er
        div     A,#1000
        move    B,A
        mul     A,#1000
        move    C,A
        add     B,#48
        out     #0,B

        move    A,$100              ; 100er
        sub     A,C
        div     A,#100
        move    B,A
        mul     A,#100
        add     C,A
        add     B,#48
        out     #0,B

        move    A,$100              ; 10er
        sub     A,C
        div     A,#10
        move    B,A
        mul     A,#10
        add     C,A
        add     B,#48
        out     #0,B

        move    A,$100              ; 1er
        sub     A,C
        move    B,A
        add     B,#48
        out     #0,B

        out     #0,#10
        
        jump    #0

        .text
       
TEXT:   "This is "
        "text line "

