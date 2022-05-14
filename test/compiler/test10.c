import "stdio.asm"

func test1() {
  var i = 0;
  var j = 0;

  for(j = 0; j < 5; j++) {
    for(i = 0; i < 5; i++) {
      putnum(i);
      if(i < 2) {
        continue;
      }
      putstr("i >= 2");
      if(i == 4) {
        break;
      }
    }
  }

  i = 0;
  while(1) {
    if(i>3) {
      break;
    }
    putnum(i);
    i++;
  }
}

func test2() {
  putstr("Should not happen");
}

func main() {
  test1();

  goto exit;
  test2();
  exit:
}

