const MAX = 100;
const MIN = 0;

func test1() {
  system(0, 0x31);
  return 1;
}

func test2() {
  system(0, 0x32);
  return 2;
}

func test3() {
  system(0, 0x33);
  return 3;
}

var tbl[] = {test1, test2, test3, MIN, MAX};

func init() {
  var c = test1;
}

func loop() {
  var val;
  var res = 0;
  var i;

  res = res + tbl[0]();
  res = res + tbl[1]();
  res = res + tbl[2]();

  val = tbl[0];
  res = res + val();

  val = tbl[1];
  res = res + val();

  val = tbl[2];
  res = res + val();

  for(i = 0; i < 3; i++) {
    res = res + tbl[i]();
    ; // dbg line
  }
  ; // dbg line
}
