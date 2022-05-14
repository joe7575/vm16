var a = 2;
var b = 3;
var c = 4;
var d = 5;

func foo(a) {
  return a;
}

func main() {
  d = (a * b) + (c * d);
  d = foo(a * b) + (c * d);
  d = (a * b) + foo(c * d);
  d = 3 + (a * b) + foo(c * d);
  d = 4 + foo(a * b) + (c * d);
}

