var var1;
var var2 = 2;
var var3 = var2 * 2;

func get_five() {
  return 5;
}

func foo(a,b) {
  var c = a;
  var d = b;
  return c * d;
}

func test_basic(a) {
  var d = 4;
  if(d > a) {
    return 0;
  }
  return 15;
}

func test_4_param(a, b, c, d) {
  return a + b + c + d;
}

func test_expr(a, b, c, d) {
  return a * get_five() + (b - 2) * c / d;
}

func test_expr2(a, b, c, d) {
  return test_basic(a + b) + (b - 2) * c / d;
}

func main() {
  var c = var1 + 1;
  var res;

  output(15, test_basic(14));
  output(1, c);
  c = (c + 3) * 2;
  output(8, c);
  system(2, var1, 0);
  system(2, var1 + 3, 0);
  var2 = input(3);
  output(12, var2);
  sleep(5);
  output(5, get_five());

  output(15, test_basic(14));
  c = 8;
  var2 = 12;
  res = test_4_param(c, c, c, var2);
  output(36, res);
  res = test_4_param(1, c, c, var2);
  output(29, res);
  //                 1 + 5        + 8 + 12
  c = test_4_param(1, get_five(), c, var2);
  output(26, c);

  // 2 * 5 + (4 - 2) * 4 / 4 = 10 + 8 / 4 = 10 + 2 = 12
  res = test_expr(2, 4, 4, 4);
  output(12, res);

  // d < (2 + 4) => 15: 15 + (4 - 2) * 4 / 4 = 15 + 2 = 17
  res = test_expr2(2, 4, 4, 4);
  output(17, res);
}

