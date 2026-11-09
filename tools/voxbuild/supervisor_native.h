#ifndef VOX_BUILD_SUPERVISOR_NATIVE_H
#define VOX_BUILD_SUPERVISOR_NATIVE_H

#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

static const char *vox_build_native_error(void) { return strerror(errno); }

/* V-generated main fills an absent or empty VEXE with the compiler path.
 * Build subprocesses must receive the caller's environment instead: tools
 * such as make give an inherited VEXE precedence over their own defaults.
 * Capture it before generated main runs, including the unset/empty distinction.
 */
static char *vox_build_caller_vexe;
static int vox_build_caller_vexe_present;
static int vox_build_caller_vexe_error;
static int vox_build_caller_vexe_restored;

__attribute__((constructor))
static void vox_build_capture_caller_vexe(void) {
    const char *value = getenv("VEXE");
    if (value != NULL) {
        vox_build_caller_vexe_present = 1;
        vox_build_caller_vexe = strdup(value);
        if (!vox_build_caller_vexe) vox_build_caller_vexe_error = ENOMEM;
    }
}

static int vox_build_restore_caller_vexe(void) {
    if (vox_build_caller_vexe_restored) return 0;
    if (vox_build_caller_vexe_error) {
        errno = vox_build_caller_vexe_error;
        return -1;
    }
    int result = vox_build_caller_vexe_present
        ? setenv("VEXE", vox_build_caller_vexe, 1) : unsetenv("VEXE");
    if (result == 0) {
        free(vox_build_caller_vexe);
        vox_build_caller_vexe = NULL;
        vox_build_caller_vexe_restored = 1;
    }
    return result;
}

static volatile sig_atomic_t vox_build_interrupted_signal;
static int vox_build_signal_depth;
static struct sigaction vox_build_previous_int, vox_build_previous_term;
static void vox_build_signal_handler(int signal_number) {
    vox_build_interrupted_signal = signal_number;
}

static int vox_build_signals_begin(void) {
    if (vox_build_signal_depth++ != 0) return 0;
    vox_build_interrupted_signal = 0;
    struct sigaction action = {0};
    action.sa_handler = vox_build_signal_handler;
    sigemptyset(&action.sa_mask);
    if (sigaction(SIGINT, &action, &vox_build_previous_int) != 0) {
        vox_build_signal_depth = 0;
        return -1;
    }
    if (sigaction(SIGTERM, &action, &vox_build_previous_term) != 0) {
        sigaction(SIGINT, &vox_build_previous_int, NULL);
        vox_build_signal_depth = 0;
        return -1;
    }
    return 0;
}

static int vox_build_interrupted(void) { return (int)vox_build_interrupted_signal; }
static void vox_build_signals_end(void) {
    if (vox_build_signal_depth > 0 && --vox_build_signal_depth == 0) {
        sigaction(SIGINT, &vox_build_previous_int, NULL);
        sigaction(SIGTERM, &vox_build_previous_term, NULL);
    }
}

/* All supervisor descriptors close across exec; an inherited build lock must
 * never outlive its owner because a compiler or browser keeps it open. */
static int vox_build_lock(const char *path, int nonblocking) {
    int fd = open(path, O_RDWR | O_CREAT | O_CLOEXEC, 0600);
    if (fd < 0) return -1;
    while (flock(fd, LOCK_EX | (nonblocking ? LOCK_NB : 0)) != 0) {
        int saved = errno;
        if (saved == EINTR && !vox_build_interrupted_signal) continue;
        close(fd);
        errno = saved;
        return saved == EWOULDBLOCK || saved == EAGAIN ? -2 : -1;
    }
    return fd;
}

static void vox_build_unlock(int fd) {
    if (fd >= 0) { flock(fd, LOCK_UN); close(fd); }
}

static int vox_build_create_exclusive(const char *path) {
    return open(path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0600);
}

static int vox_build_write_all(int fd, const char *data, int64_t length) {
    while (length > 0) {
        ssize_t written = write(fd, data, (size_t)length);
        if (written < 0 && errno == EINTR) continue;
        if (written <= 0) return -1;
        data += written;
        length -= written;
    }
    return 0;
}

static int vox_build_close(int fd) { return close(fd); }

/* Sampling happens every 100 ms even during long builds. Keep the capture
 * buffer explicitly owned instead of accumulating shell/capture allocations
 * in a build tool compiled with -gc none. */
static char *vox_build_process_snapshot(int *exit_code) {
    int output[2];
    if (pipe(output) != 0) return NULL;
    pid_t pid = fork();
    if (pid == 0) {
        close(output[0]);
        if (dup2(output[1], STDOUT_FILENO) < 0 ||
            dup2(output[1], STDERR_FILENO) < 0) _exit(126);
        if (output[1] > STDERR_FILENO) close(output[1]);
        execlp("ps", "ps", "-axo", "pid=,ppid=,pgid=,rss=,stat=,lstart=", (char *)NULL);
        _exit(127);
    }
    int saved = errno;
    close(output[1]);
    if (pid < 0) { close(output[0]); errno = saved; return NULL; }
    size_t size = 0, capacity = 4096;
    char *buffer = malloc(capacity);
    if (!buffer) goto failed;
    for (;;) {
        if (size + 1 == capacity) {
            size_t next = capacity * 2;
            if (next <= capacity) { errno = ENOMEM; goto failed; }
            char *larger = realloc(buffer, next);
            if (!larger) goto failed;
            buffer = larger;
            capacity = next;
        }
        ssize_t count = read(output[0], buffer + size, capacity - size - 1);
        if (count < 0 && errno == EINTR) continue;
        if (count < 0) goto failed;
        if (count == 0) break;
        size += (size_t)count;
    }
    close(output[0]);
    int status;
    while (waitpid(pid, &status, 0) < 0) {
        if (errno != EINTR) { free(buffer); return NULL; }
    }
    buffer[size] = '\0';
    *exit_code = WIFSIGNALED(status) ? 128 + WTERMSIG(status) : WEXITSTATUS(status);
    return buffer;
failed:
    saved = errno;
    close(output[0]);
    kill(pid, SIGKILL);
    while (waitpid(pid, NULL, 0) < 0 && errno == EINTR) {}
    free(buffer);
    errno = saved;
    return NULL;
}

static void vox_build_free_snapshot(char *buffer) { free(buffer); }

static int vox_build_replace(const char *source, const char *target) {
    return rename(source, target);
}

static int vox_build_exchange(const char *source, const char *target) {
#ifdef __APPLE__
    return renameatx_np(AT_FDCWD, source, AT_FDCWD, target, RENAME_SWAP);
#else
    (void)source; (void)target;
    errno = ENOSYS;
    return -1;
#endif
}

/* Commands receive literal argv and a private environment. No shell quoting or
 * parent-process environment mutation is involved. Each owns a new session. */
static int vox_build_spawn(char *const argv[], char *const environment[],
                           const char *cwd, const char *log, int append,
                           const char *input, int64_t input_length, int background) {
    int input_pipe[2] = {-1, -1};
    int log_fd = -1;
    if (input_length >= 0 && pipe(input_pipe) != 0) return -1;
    if (log && *log) {
        log_fd = open(log, O_WRONLY | O_CREAT | O_CLOEXEC | (append ? O_APPEND : O_TRUNC), 0600);
        if (log_fd < 0) {
            if (input_pipe[0] >= 0) { close(input_pipe[0]); close(input_pipe[1]); }
            return -1;
        }
    }
    pid_t pid = fork();
    if (pid == 0) {
        if (setsid() < 0) _exit(126);
        if (cwd && *cwd && chdir(cwd) != 0) _exit(126);
        if (input_pipe[0] >= 0) {
            close(input_pipe[1]);
            if (dup2(input_pipe[0], STDIN_FILENO) < 0) _exit(126);
            close(input_pipe[0]);
        } else if (background) {
            int null_fd = open("/dev/null", O_RDONLY);
            if (null_fd < 0 || dup2(null_fd, STDIN_FILENO) < 0) _exit(126);
            if (null_fd != STDIN_FILENO) close(null_fd);
        }
        if (log_fd >= 0) {
            if (dup2(log_fd, STDOUT_FILENO) < 0 || dup2(log_fd, STDERR_FILENO) < 0) _exit(126);
            if (log_fd > STDERR_FILENO) close(log_fd);
        }
        extern char **environ;
        if (environment) environ = (char **)environment;
        execvp(argv[0], argv);
        fprintf(stderr, "Cannot execute %s: %s\n", argv[0], strerror(errno));
        _exit(127);
    }
    int saved = errno;
    if (log_fd >= 0) close(log_fd);
    if (input_pipe[0] >= 0) {
        close(input_pipe[0]);
        if (pid >= 0) {
            /* Suppress SIGPIPE only in the writer; a failed exec is reported by
             * the child's exit and must not kill the supervisor. */
            struct sigaction ignore = {0}, previous;
            ignore.sa_handler = SIG_IGN;
            sigemptyset(&ignore.sa_mask);
            sigaction(SIGPIPE, &ignore, &previous);
            vox_build_write_all(input_pipe[1], input, input_length);
            sigaction(SIGPIPE, &previous, NULL);
        }
        close(input_pipe[1]);
    }
    errno = saved;
    return (int)pid;
}

static int vox_build_poll(int pid, int *code, int blocking) {
    int status = 0;
    pid_t result;
    do { result = waitpid((pid_t)pid, &status, blocking ? 0 : WNOHANG); } while (result < 0 && errno == EINTR);
    if (result <= 0) return (int)result;
    *code = WIFSIGNALED(status) ? -WTERMSIG(status) : WEXITSTATUS(status);
    return 1;
}

static int vox_build_kill(int pid, int group) {
    return kill(group ? -(pid_t)pid : (pid_t)pid, SIGKILL);
}

static int vox_build_terminate(int pid) { return kill((pid_t)pid, SIGTERM); }

#endif
