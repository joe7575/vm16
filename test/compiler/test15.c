import "stdio.asm"

func init() {
  var a = 1;
  var b = 2;

  b = (b + 3) * 2;

  if((b mod 10) == 2) {
    putstr("ok");
  }

  if(b mod 10 == 2) {
    putstr("ok");
  }

  if((a == 0) or (b == 2)) {
    putstr("ok");
  }

  if(true) {
    putstr("ok");
  }

  if(false) {
    putstr("err");
  }
}

func loop() {
}