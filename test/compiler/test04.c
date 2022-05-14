const MAX = 32;

func main() {
  var i = 1;
  var ptr = 0x100;

  output(1, i);
  while(i < MAX) {
    i = i + 1;
    i = *ptr;

    _asm_ {
      move A, #3
      xor $100, [X]++
      jump 0
    }
  }
}
