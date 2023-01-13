# VM16 Computer

The vm16 mod comes with a computer, a lamp, and a switch block for training purposes. It can be used to get familiar with the programming environment. The VM16 demo CPU is a 16-bit CPU with 1024 words memory. This should be sufficient to learn the programming basics. 

A more demanding CPU/Controller environment is [Beduino](https://github.com/joe7575/beduino).


## Manual

- Craft the 5 blocks "VM16 Programmer", "VM16 File Server", "VM16 Demo Computer", VM16 On/Off Switch" and "VM16 Color Lamp".
- Place "VM16 Demo Computer", VM16 On/Off Switch" and "VM16 Color Lamp" next to each other. The computer searches for I/O blocks in an area with a radius of 3 blocks. 
- The switch is used as input block for the computer, the lamp as output block.
- Give lamp and switch an I/O address. For the provided example, address '1' is used for both blocks.
- You can add further I/O blocks for you own programs with other addresses.
- Place the server anywhere.
- Connect the programmer with server and CPU by left-clicking with the wielded programmer on server and CPU block.
- Place the programmer anywhere.



## VM16 Programmer/Editor/Debugger

See [Beduino](https://github.com/joe7575/beduino).

### VM16 On/Off Switch

The switch sends a '1' to the computer when it is turned on and a '0' when it is turned off. 

```assembly
loop:
  nop          ; 100 ms delay
  in   B, #1   ; read switch value
  bze  B, loop
  ...
```



### VM16 Color Lamp

This lamp block can light up in different colors. To do this, values from 1-64 must be sent to the block using the `out` instruction. The value 0 switches the lamp off.

```assembly
  move A, #00  ; color value in A
loop:
  nop          ; 100 ms delay
  and  A, #$3F ; values from 1 to 64
  add  A, #01
  out  #01, A  ; output color value
  jump loop
```
