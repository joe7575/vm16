; Hello world for the Telewriter v1.0
;

        .code

START:  move    X, #TEXT

LOOP:   out     #0, [X]    
        bnze    [X]+, +LOOP
        halt

        .text
       
TEXT:   "Hello "
        "World\n\0"

