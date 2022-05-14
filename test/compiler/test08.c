import "stdio.asm"

func main() {
  var a = 1;
  var b = 2;

  if((a == 0) or (b == 2)) {
    putstr("ok");
  } else {
    putstr("error");
  }

  if((a == 1) and (b == 2)) {
    putstr("ok");
  } else {
    putstr("error");
  }

  if((a == 0) || (b == 2)) {
    putstr("ok");
  }

  if((a == 1) && (b == 2)) {
    putstr("ok");
  }
}
