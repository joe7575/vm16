// Labels and Values
// https://gcc.gnu.org/onlinedocs/gcc/Labels-as-Values.html

func init() {
}

static var arr[] = {&&mark1, &&mark2, &&mark3};


func loop() {
  var addr = &&mark3;

  goto *arr[2];
  goto *addr;

  goto mark1;

  while(1) {
    mark1:
      system(0, 0x31);
      break;

    mark2:
      system(0, 0x32);
      break;

    mark3:
      system(0, 0x33);
      goto mark2;
      break;
  }
}
