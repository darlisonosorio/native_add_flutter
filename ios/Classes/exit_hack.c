#include <stdlib.h>
#include "exit_hack.h"

int original_stdout;
int original_stderr;

void redirect_streams(char* stdout_path, char* stderr_path) {
    printf("REDIRECT CALLED!\n");
    original_stdout = dup(STDOUT_FILENO);
    original_stderr = dup(STDERR_FILENO);
    freopen(stdout_path, "w", stdout);
    freopen(stderr_path, "w", stderr);
}

void restore_streams() {
    fflush(stdout);
    fflush(stderr);
    dup2(original_stdout, STDOUT_FILENO);
    dup2(original_stderr, STDERR_FILENO);
    printf("RESTORE CALLED!\n");
}

void set_env_var(char* key, char* value) {
    setenv(key, value, 1);
}