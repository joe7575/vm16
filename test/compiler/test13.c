func foo1(a) {
  return a[2];
}

func foo2(a, b) {
  return b[2];
}

func foo3(a, b, c) {
  return c[2];
}

func foo4() {
  var c;
  var arr[4];

  arr[0] = 0x11;
  arr[1] = 0x22;
  arr[2] = 0x33;
  arr[3] = 0x44;

  c = arr[2] + arr[3];
  arr[0] = c;
  return arr[0];
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
  foo4();
}

func loop() {
}
