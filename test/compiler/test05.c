var arr1[4];
var arr2[4] = {1, 2, 3, 4};
var out[6];
var str = "Hello Joe!";

func memcpy(dst, src, num) {
  while(num > 0) {
    *dst = *src;
    dst++;
    src++;
    num--;
  }
}

func putval(val) {
  var c;
  var r = val;
  var i = 0;

  if(val == 0) {
    output(0, 0x30);
    return;
  }

  while(r > 0) {
    c = r % 10;
    r = r / 10;
    out[i] = c + 0x30;
    i++;
  }
  for(; i > 0; i--) {
    output(0, out[i-1]);
  }
}

func putstr(s) {
  var i;

  while(s[i] != 0) {
    output(0, s[i]);
    i++;
  }
}

func main() {
  var i;
  var c = i + 1;
  var p1 = arr1;
  var p2 = str;

  memcpy(arr1, arr2, 4);

  for(i = 0; i < 4; i++) {
    putval(arr1[i]);
  }
  output(0, '  ');
  putval(0x55AA);
  output(0, '  ');
  putstr(str);
  output(0, '  ');
  putstr(p2);
  putstr("Hello world!");
}
