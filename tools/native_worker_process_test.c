// Copyright (c) 2026, Vox contributors
// SPDX-License-Identifier: BSD-2-Clause
#define _GNU_SOURCE
#include "../browserjs/worker_process.h"
#include <JavaScriptCore/JavaScript.h>
#include <assert.h>
#include <stdio.h>
#include <time.h>
#ifdef __linux__
#include <sys/prctl.h>
#endif

static const char *self;

static double now(void)
{
    struct timespec value;
    assert(clock_gettime(CLOCK_MONOTONIC, &value) == 0);
    return value.tv_sec + value.tv_nsec / 1e9;
}

static int read_frame(vox_js_worker_process *p, uint32_t *kind,
    unsigned char **bytes, size_t *length)
{
    double deadline = now() + 5;
    while (now() < deadline) {
        if (vox_js_worker_flush(p) < 0) return -1;
        int result = vox_js_worker_receive(p, kind, bytes, length);
        if (result) return result;
        assert(vox_js_worker_wait(p, 10) >= 0);
    }
    assert(!"worker transport deadline");
    return -1;
}

static void expect(vox_js_worker_process *p, uint32_t expected_kind,
    const void *expected, size_t expected_length)
{
    uint32_t kind;
    unsigned char *bytes;
    size_t length;
    assert(read_frame(p, &kind, &bytes, &length) == 1);
    assert(kind == expected_kind && length == expected_length);
    assert(!length || memcmp(bytes, expected, length) == 0);
    free(bytes);
}

static int helper(void)
{
    vox_js_worker_process *p = vox_js_worker_begin_child();
    if (!p) return 64;
    JSGlobalContextRef context = JSGlobalContextCreate(NULL);
    assert(context);
    assert(vox_js_worker_queue(p, 1, NULL, 0) == 0);
    for (;;) {
        uint32_t kind;
        unsigned char *bytes;
        size_t length;
        int result = read_frame(p, &kind, &bytes, &length);
        if (result == 2) break;
        assert(result == 1);
        if (kind == 2) {
            char *source = calloc(length + 1, 1);
            assert(source);
            memcpy(source, bytes, length);
            JSStringRef script = JSStringCreateWithUTF8CString(source);
            free(source);
            JSValueRef exception = NULL;
            JSValueRef value = JSEvaluateScript(context, script, NULL, NULL, 1, &exception);
            JSStringRelease(script);
            JSStringRef text = JSValueToStringCopy(context, exception ? exception : value, NULL);
            size_t capacity = JSStringGetMaximumUTF8CStringSize(text);
            char *output = malloc(capacity);
            assert(output);
            size_t count = JSStringGetUTF8CString(text, output, capacity);
            assert(count > 0);
            assert(vox_js_worker_queue(p, exception ? 5 : 3, (unsigned char *)output, count - 1) == 0);
            free(output);
            JSStringRelease(text);
        } else if (kind == 4) {
            assert(vox_js_worker_queue(p, kind, bytes, length) == 0);
        } else if (kind == 6) {
            assert(length == 4);
            int fd = (int)vox_js_worker_u32(bytes);
            unsigned char closed = fcntl(fd, F_GETFD) < 0 && errno == EBADF;
            assert(vox_js_worker_queue(p, kind, &closed, 1) == 0);
        } else if (kind == 7) {
            free(bytes);
            JSGlobalContextRelease(context);
            vox_js_worker_destroy(p);
            return 42;
        } else if (kind == 8) {
            // Report actual execution before entering a non-cooperative JS loop.
            assert(vox_js_worker_queue(p, 8, NULL, 0) == 0);
            while (vox_js_worker_flush(p) == 0) vox_js_worker_wait(p, 10);
            JSStringRef script = JSStringCreateWithUTF8CString("for (;;) {} ");
            JSEvaluateScript(context, script, NULL, NULL, 1, NULL);
            abort();
        } else abort();
        free(bytes);
    }
    JSGlobalContextRelease(context);
    vox_js_worker_destroy(p);
    return 0;
}

static vox_js_worker_process *start(void)
{
    vox_js_worker_process *p = vox_js_worker_spawn(self);
    assert(p && p->pid > 0);
    expect(p, 1, NULL, 0);
    return p;
}

static void script(vox_js_worker_process *p, const char *source,
    uint32_t kind, const char *result)
{
    assert(vox_js_worker_queue(p, 2, (const unsigned char *)source, strlen(source)) == 0);
    expect(p, kind, result, strlen(result));
}

static void test_execution_isolation_and_binary_messages(void)
{
    vox_js_worker_process *a = start(), *b = start();
    script(a, "globalThis.privateValue = 42", 3, "42");
    script(b, "typeof privateValue", 3, "undefined");
    script(a, "privateValue + 1", 3, "43");
    script(a, "throw new TypeError('worker failure')", 5, "TypeError: worker failure");
    size_t size = 3 * 1024 * 1024 + 17;
    unsigned char *data = malloc(size);
    assert(data);
    for (size_t i = 0; i < size; ++i) data[i] = (unsigned char)(i * 113);
    for (unsigned i = 0; i < 3; ++i) {
        data[0] = (unsigned char)i;
        assert(vox_js_worker_queue(a, 4, data, size) == 0);
    }
    for (unsigned i = 0; i < 3; ++i) {
        data[0] = (unsigned char)i;
        expect(a, 4, data, size);
    }
    free(data);
    vox_js_worker_destroy(a); vox_js_worker_destroy(b);
    puts("PASS separate JavaScript agents, exceptions, ordered binary frames and copied queue ownership");
}

static void write_bytes(int fd, const void *bytes, size_t length)
{
    assert(write(fd, bytes, length) == (ssize_t)length);
}

static void test_fragmentation_and_truncated_frames(void)
{
    int pair[2];
    assert(socketpair(AF_UNIX, SOCK_STREAM, 0, pair) == 0);
    vox_js_worker_process *p = vox_js_worker_channel(pair[0]);
    assert(p);
    unsigned char frame[17] = {'V','X','W','1',0,0,0,9,0,0,0,5,0,1,255,0,3};
    for (size_t i = 0; i < sizeof frame; ++i) {
        write_bytes(pair[1], frame + i, 1);
        uint32_t kind; unsigned char *bytes; size_t length;
        int result = vox_js_worker_receive(p, &kind, &bytes, &length);
        assert(result == (i == sizeof frame - 1 ? 1 : 0));
        if (result == 1) {
            assert(kind == 9 && length == 5 && memcmp(bytes, frame + 12, 5) == 0);
            free(bytes);
        }
    }
    close(pair[1]);
    uint32_t kind; unsigned char *bytes; size_t length;
    assert(vox_js_worker_receive(p, &kind, &bytes, &length) == 2);
    vox_js_worker_destroy(p);
    for (size_t prefix = 1; prefix < sizeof frame; ++prefix) {
        assert(socketpair(AF_UNIX, SOCK_STREAM, 0, pair) == 0);
        p = vox_js_worker_channel(pair[0]); assert(p);
        write_bytes(pair[1], frame, prefix); close(pair[1]);
        assert(vox_js_worker_receive(p, &kind, &bytes, &length) == -1 && errno == EPROTO);
        assert(bytes == NULL && length == 0 && kind == 0);
        assert(vox_js_worker_receive(p, &kind, &bytes, &length) == -1);
        vox_js_worker_destroy(p);
    }
    puts("PASS byte-fragmented delivery, clean EOF and every truncated-frame boundary");
}

static void test_invalid_frames_and_queue_limits(void)
{
    for (int bad = 0; bad < 3; ++bad) {
        int pair[2]; assert(socketpair(AF_UNIX, SOCK_STREAM, 0, pair) == 0);
        vox_js_worker_process *p = vox_js_worker_channel(pair[0]); assert(p);
        unsigned char header[12] = {'V','X','W','1',0,0,0,1,0,0,0,0};
        if (bad == 0) header[0] = '?';
        if (bad == 1) header[7] = 0;
        if (bad == 2) vox_js_worker_put_u32(header + 8, VOX_JS_WORKER_MAX_FRAME + 1);
        write_bytes(pair[1], header, sizeof header);
        uint32_t kind; unsigned char *bytes; size_t length;
        assert(vox_js_worker_receive(p, &kind, &bytes, &length) == -1 && errno == EPROTO);
        assert(p->payload == NULL);
        close(pair[1]); vox_js_worker_destroy(p);
    }
    int pair[2]; assert(socketpair(AF_UNIX, SOCK_STREAM, 0, pair) == 0);
    vox_js_worker_process *p = vox_js_worker_channel(pair[0]); assert(p);
    size_t size = VOX_JS_WORKER_MAX_FRAME;
    unsigned char *data = calloc(size, 1); assert(data);
    assert(vox_js_worker_queue(p, 0, NULL, 0) == -1 && errno == EINVAL);
    assert(vox_js_worker_queue(p, 1, data, size + 1) == -1 && errno == EINVAL);
    for (int i = 0; i < 3; ++i) assert(vox_js_worker_queue(p, 1, data, size) == 0);
    size_t previous = p->allocated;
    assert(vox_js_worker_queue(p, 1, data, size) == -1 && errno == ENOBUFS);
    assert(p->allocated == previous && p->allocated < VOX_JS_WORKER_MAX_QUEUE);
    double started_at = now();
    for (int i = 0; i < 50; ++i) assert(vox_js_worker_flush(p) == 0);
    assert(now() - started_at < .5);
    assert(p->allocated == previous); // A partial write still owns its full allocation.
    close(pair[1]);
    assert(vox_js_worker_flush(p) == -1); // No process-wide SIGPIPE.
    free(data); vox_js_worker_destroy(p);
    puts("PASS invalid headers, allocation bounds, stalled peer and SIGPIPE containment");
}

static void test_spawn_descriptor_and_termination(void)
{
    int fd = open("/dev/null", O_RDONLY); assert(fd >= 0);
    int high = fcntl(fd, F_DUPFD, 128); assert(high >= 128);
    close(fd);
    vox_js_worker_process *p = start();
    unsigned char encoded[4]; vox_js_worker_put_u32(encoded, (uint32_t)high);
    assert(vox_js_worker_queue(p, 6, encoded, sizeof encoded) == 0);
    unsigned char yes = 1; expect(p, 6, &yes, 1);
    close(high);
    assert(vox_js_worker_queue(p, 8, NULL, 0) == 0);
    expect(p, 8, NULL, 0);
    pid_t pid = p->pid;
    double started_at = now(); vox_js_worker_destroy(p);
    assert(now() - started_at < 2);
    assert(waitpid(pid, NULL, WNOHANG) == -1 && errno == ECHILD);
    p = start(); pid = p->pid;
    assert(vox_js_worker_queue(p, 7, NULL, 0) == 0);
    uint32_t kind; unsigned char *bytes; size_t length;
    assert(read_frame(p, &kind, &bytes, &length) == 2);
    vox_js_worker_destroy(p);
    assert(waitpid(pid, NULL, WNOHANG) == -1 && errno == ECHILD);
    assert(!vox_js_worker_spawn("/nonexistent/vox-worker") && errno == ENOENT);
    assert(!vox_js_worker_spawn("") && errno == EINVAL);
    // Reserved endpoint numbers must also work in a headless launcher whose
    // stdin/stdout have already been closed before socketpair()/pipe().
    pid_t launcher = fork(); assert(launcher >= 0);
    if (!launcher) {
        close(STDIN_FILENO); close(STDOUT_FILENO);
        vox_js_worker_process *nested = start();
        script(nested, "6 * 7", 3, "42");
        vox_js_worker_destroy(nested);
        _exit(0);
    }
    int status = 0;
    assert(waitpid(launcher, &status, 0) == launcher);
    assert(WIFEXITED(status) && WEXITSTATUS(status) == 0);
    puts("PASS descriptor isolation, closed standard input/output, busy JavaScript termination, crash reaping and spawn failures");
}

static void test_parent_lifetime(void)
{
    int report[2]; assert(pipe(report) == 0);
    pid_t launcher = fork(); assert(launcher >= 0);
    if (!launcher) {
        close(report[0]);
        vox_js_worker_process *p = start();
        assert(vox_js_worker_queue(p, 8, NULL, 0) == 0);
        expect(p, 8, NULL, 0);
        write_bytes(report[1], &p->pid, sizeof p->pid);
        _exit(0); // Deliberately skip cleanup while the helper executes JS.
    }
    close(report[1]);
    pid_t child; assert(read(report[0], &child, sizeof child) == (ssize_t)sizeof child);
    close(report[0]);
    assert(waitpid(launcher, NULL, 0) == launcher);
    double deadline = now() + 5;
#ifdef __linux__
    // Linux test containers need not have a reaping PID 1. main() adopts
    // orphaned helpers so that their successful exit can be observed directly.
    pid_t reaped;
    do { reaped = waitpid(child, NULL, WNOHANG); if (!reaped) usleep(10000); }
    while (!reaped && now() < deadline);
    assert(reaped == child);
#endif
    while (kill(child, 0) == 0 && now() < deadline) usleep(10000);
    assert(kill(child, 0) == -1 && errno == ESRCH);
    puts("PASS browser death stops a non-cooperative JavaScript helper");
}

int main(int argc, char **argv)
{
    if (argc == 2 && !strcmp(argv[1], VOX_JS_WORKER_ROLE)) return helper();
    assert(argc == 1);
#ifdef __linux__
    assert(prctl(PR_SET_CHILD_SUBREAPER, 1) == 0);
#endif
    self = argv[0];
    assert(!vox_js_worker_begin_child());
    test_execution_isolation_and_binary_messages();
    test_fragmentation_and_truncated_frames();
    test_invalid_frames_and_queue_limits();
    test_spawn_descriptor_and_termination();
    test_parent_lifetime();
    return 0;
}
