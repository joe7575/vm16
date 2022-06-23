var route[] = {0,0,0};
var c;

func init() {
  c = 1;
}

func calc_height2(dest_floor) {
  return dest_floor;
}

func move_lift(floor) {
  route[1] = calc_height2(floor);
}

func loop() {
  move_lift(2);
}