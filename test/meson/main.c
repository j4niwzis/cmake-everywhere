#include <basu/sd-bus.h>
#include <stdio.h>

int main(void) {
  sd_bus *bus = NULL;
  /* Opening it needs a bus to open. Asking for an error back for a call
     that cannot work is a call into the library, which is what is being
     checked here: that it was built, linked and can be reached. */
  int status = sd_bus_new(&bus);
  if (status < 0) {
    printf("sd_bus_new: %d\n", status);
    return 1;
  }
  sd_bus_unref(bus);
  printf("sd-bus answered\n");
  return 0;
}
