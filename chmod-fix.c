#include <dlfcn.h>
#include <sys/stat.h>

static int (*real_chmod)(const char *path, mode_t mode);

int chmod(const char *path, mode_t mode) {
  real_chmod = dlsym(RTLD_NEXT, "chmod");
  return real_chmod(path, mode & 0777);
}
