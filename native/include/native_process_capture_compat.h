#pragma once

// Match os's bodyless V bindings and execute_capture_legacy.h. These declarations
// can share a FastC unit with prototypes emitted from those bindings; adding
// pointee const qualifiers makes the function types incompatible.
int v_os_execute_capture_start(char *command, int *child_pid, int *read_fd);
int v_os_exec_capture_start(char **argv, int *child_pid, int *read_fd);
