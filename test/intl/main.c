#include <libintl.h>
#include <string.h>
#if !defined(G_INTL_STATIC_COMPILATION) || !defined(gettext)
#error The proxy-libintl target must supply its own header and static interface
#endif
int main(void) {
  if (strcmp(gettext("hello"), "hello") != 0) return 1;
  if (strcmp(ngettext("item", "items", 1), "item") != 0) return 2;
  if (strcmp(ngettext("item", "items", 2), "items") != 0) return 3;
  return 0;
}
