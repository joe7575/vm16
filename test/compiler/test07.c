var val1 = 1;
var ptr1;
static var arr[2];

static func test() {
  output(0, '12');
}

func main() {
  var ptr2 = test;
  ptr1 = test;
  arr[1] = test;

  test();
  ptr1();
  ptr2();
  ptr1 = arr[2];
  ptr1();
  output(0, '34');
}
