func init() {
}

func loop() {
  var addr = &&mark3;

  // 	https://gcc.gnu.org/onlinedocs/gcc/Labels-as-Values.html
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
