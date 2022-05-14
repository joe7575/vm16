const SEND_MSG = 2;
static var buff[3];

static func test(a) {
  return;
}

func send_msg(port, topic, size, ptr) {
  buff[0] = topic;
  buff[1] = size;
  buff[2] = ptr;
  system(SEND_MSG, port, buff);
  test(2);
}
