#pragma once

// These declarations must match vlib/os/execute_capture_legacy.h in the V
// used to build the browser byte-for-byte; FastC emits calls to them, and
// any const mismatch is a hard C error when both headers land in one unit.
int v_os_execute_capture_start(char *cmd, int *child_pid, int *read_fd);
int v_os_exec_capture_start(char **argv, int *child_pid, int *read_fd);
