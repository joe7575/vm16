; VM Test Sequence v1.0
;

        .code

START:  move    A, #$1111
        move    B, #$2222
        move    C, #$3333
        move    D, #$4444

        add     A,B         ; 3333
        sub     D,C         ; 1111
        mul     D,#3        ; 3333
        div     A,#3        ; 1111

        call    #subr1
        res
        push    #lbl1
        bnze    A,#subr2
lbl1:   res

        push    #lbl2
        bpos    A,#subr3
lbl2:   push    #lbl3
        bneg    A,#subr4
lbl3:   res
        
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
