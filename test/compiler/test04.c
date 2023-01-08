const MAX = 32;

var cnt = 0;

func main() {
  var i = 1;
  var ptr = 0x100;

  output(1, i);
  while(i < MAX) {
    i = i + 1;
    i = *ptr;

    _asm_ {
      move A, #3
      move A, cnt ; global variable
      move A, i   ; local variable
      xor $100, [X]++
    }
  }
}
