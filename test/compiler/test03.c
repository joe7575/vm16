var var1 = 0;
var Drehzahl;

func get_char(c) {
  var1 = c;
  if(c > 20) {
    return 1;
  } else {
    return 65 + c;
  }
  var1 = var1 + 1;
}

func foo() {
  var a = -1;
  var b = 2;

  if(a == ~0xffff){
    output(0, 0x41);
  } else {
    output(0, 0x42);
  }
}

func main() {
  var i = 1;
  var c;

  sleep(5);
  foo();
  while(i < 32) {
    c = get_char(i);
    output(0, c);
    i = i + 1;
  }
}

