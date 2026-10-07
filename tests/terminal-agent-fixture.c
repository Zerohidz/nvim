/* A raw PTY byte sink, compiled as codex/claude/shell by the test runner. */
#include <stdio.h>
#include <termios.h>
#include <unistd.h>
int main(int argc, char **argv) {
  if (argc < 2) return 1;
  struct termios term;
  tcgetattr(STDIN_FILENO, &term);
  cfmakeraw(&term);
  tcsetattr(STDIN_FILENO, TCSANOW, &term);
  FILE *log = fopen(argv[1], "a");
  if (!log) return 1;
  write(STDOUT_FILENO, "READY\r\n", 7);
  unsigned char bytes[128];
  ssize_t count;
  while ((count = read(STDIN_FILENO, bytes, sizeof(bytes))) > 0) {
    for (ssize_t i = 0; i < count; ++i) fprintf(log, "%02x", bytes[i]);
    fflush(log);
  }
  fclose(log);
  return 0;
}
