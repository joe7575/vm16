import "stdio.asm"

const MAX1 = 10;
const MAX2 = 2 * MAX1;
static const MAX3 = (MAX2 + 1) / 2;

var arr1[MAX1];
var arr2[MAX3+1] = {0,0,0,0};
static var arr3[2] = {0,0,0,0};

func init() {
  var arr4[3];

  putnum(MAX1);
  putchar(' ');
  putnum(MAX2);
  putchar(' ');
  putnum(MAX3);
  putchar(' ');
  putnum(sizeof(arr1));
  putchar(' ');
  putnum(sizeof(arr2));
  putchar(' ');
  putnum(sizeof(arr3));
  putchar(' ');
  putnum(sizeof(arr4));
}

func loop() {
}
