import "string.asm"
import "stdio.asm"

static var arr[10];

func main() {
  strcpy(arr, "Hello world!");
  putstr(arr);
}
