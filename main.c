#include <libgen.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

void create_parent_dir(const char *path) {
  char *parent_dir = (char *)malloc(sizeof(char) * strlen(path) + 1);
  strcpy(parent_dir, path);
  parent_dir = dirname(parent_dir);
  mkdir(parent_dir, 0755);
  free(parent_dir);
}

char *init_data_path() {
  const char *base_path = getenv("XDG_DATA_HOME");
  const char *to_join = "/kasumi-audit/paths.toml";

  if (!base_path) {
    base_path = getenv("HOME");
    if (!base_path) {
      return NULL;
    }
    to_join = "/.local/share/kasumi-audit/paths.toml";
  }

  long int size = strlen(base_path) + strlen(to_join) + 1; // + 1 for \0
  char *result_path = (char *)malloc(sizeof(char) * size);

  if (!result_path) {
    return NULL;
  }

  snprintf(result_path, size, "%s%s", base_path, to_join);

  create_parent_dir(result_path);
  return result_path;
}

void deinit_string(char *data_path) { free(data_path); }

char *load_string_from_path(const char *path) {
  char *buffer;
  long length;
  FILE *file = fopen(path, "r");
  if (file) {
    fseek(file, 0, SEEK_END);
    long length = ftell(file);
    fseek(file, 0, SEEK_SET);
    buffer = (char *)malloc(length * sizeof(char));
    if (buffer) {
      fread(buffer, 1, length, file);
    }
  }
  fclose(file);
  return buffer;
}

int main() {
  char *data_path = init_data_path();

  if (!data_path) {
    return 1;
  }

  char *data = load_string_from_path(data_path);

  printf("%s\n", data_path);
  printf("%s\n", data);

  // find the config file path
  // open the file and convert it to a struct
  // audit all files in the home folder, ignoring paths loaded from the file
  // display the result

  deinit_string(data);
  deinit_string(data_path);

  return 0;
}
