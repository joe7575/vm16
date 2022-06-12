func foo1(a) {
  return a[2];
}

func foo2(a, b) {
  return b[2];
}

func foo3(a, b, c) {
  return c[2];
}

func init() {
  var arr1[2];
  var c;

  arr1[0] = 1;
  c = arr1;
  c = *arr1;
  c = arr1[1];
  foo1(arr1);
  foo2(1, arr1);
  foo3(1, 2, arr1);
}

func loop() {
}
