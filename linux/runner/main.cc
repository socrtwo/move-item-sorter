#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/types.h>

#include "fl_my_application.h"

int main(int argc, char** argv) {
  g_autoptr(FlMyApplication) app = fl_my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
