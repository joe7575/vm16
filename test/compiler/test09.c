import "comm.c"
static var idx = 0;


func init() {
  system(0, 'In');
  system(0, 'it');
}

func loop() {
  if(input(1) == 1) {
    output(1, idx);
    idx = (idx + 1) % 64;
  } else {
    output(1, 0);
  }
}
