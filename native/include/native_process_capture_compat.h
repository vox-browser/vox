#pragma once

int v_os_execute_capture_start(const char *command, int *child_pid, int *read_fd);
int v_os_exec_capture_start(char *const argv[], int *child_pid, int *read_fd);
