        .code

        nop
        dly
        sys 0
        int 0
        halt
        jump 2
        int $10
        int 100
        move A, B
        move B, #0
        move C, #1
        move D, 2
        move X, #2
        move Y, $2
        move SP, #$2
        move PC, 20
        move [X], #20
        move [Y], $20
        move [X]+, #$20
        move [Y]+, #$20
        move [SP+0], 0000
        move [SP+1], 1234
        move [SP+2], 1234
        move [SP+$10], 1234

START:  move    A, #$1111
        move    B, #$2222
        move    C, #$3333
        move    D, #$4444
        dly     10

        add     A,B         ; 3333
        sub     D,C         ; 1111
        mul     D,#3        ; 3333
        div     A,#3        ; 1111
        dly

        call    #subr1
        shl     A, #1
        push    #lbl1
        bnze    A,#subr2
lbl1:   dly

        push    #lbl2
        bpos    A,#subr3
lbl2:   push    #lbl3
        bneg    A,#subr4
lbl3:   sys     123
        
        jump exit       


subr1:  inc     A           ; 1112
        ret

subr2:  shl     A, #1       ; 2224
        ret

subr3:  not     A           ; DDDB
        ret

subr4:  xor     A, #$FFFF
        ret

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
