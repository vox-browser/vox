// The TLS reader releases its mutex while idle. A queued wake preserves data
// which a concurrent TLS write may decrypt before the reader polls the socket.
#ifndef VOX_H2_WAKE_H
#define VOX_H2_WAKE_H
#if !defined(_WIN32)
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <pthread.h>
#include <stdlib.h>
#include <unistd.h>
typedef struct {
    pthread_mutex_t mutex;
    int input, output, references, closed;
} vox_h2_wake;
static void *vox_h2_wake_create(void) {
    int fds[2];
    if (pipe(fds)) return NULL;
    for (int i = 0; i < 2; ++i) {
        int flags = fcntl(fds[i], F_GETFL);
        if (flags < 0 || fcntl(fds[i], F_SETFL, flags | O_NONBLOCK) < 0 ||
            fcntl(fds[i], F_SETFD, FD_CLOEXEC) < 0) {
            close(fds[0]); close(fds[1]); return NULL;
        }
    }
    vox_h2_wake *w = calloc(1, sizeof(*w));
    if (!w) { close(fds[0]); close(fds[1]); return NULL; }
    if (pthread_mutex_init(&w->mutex, NULL)) {
        close(fds[0]); close(fds[1]); free(w); return NULL;
    }
    w->input = fds[0]; w->output = fds[1]; w->references = 1;
    return w;
}
// Caller holds the transport I/O mutex while retaining or releasing its owner.
static void *vox_h2_wake_retain(void *handle) {
    vox_h2_wake *w = handle;
    pthread_mutex_lock(&w->mutex); ++w->references; pthread_mutex_unlock(&w->mutex);
    return handle;
}
static void vox_h2_wake_signal(void *handle) {
    if (!handle) return;
    vox_h2_wake *w = handle;
    unsigned char byte = 1;
    // A full pipe already represents a pending wake. Never block the writer.
    while (write(w->output, &byte, 1) < 0 && errno == EINTR) {}
}
static void vox_h2_wake_release(void *handle) {
    vox_h2_wake *w = handle;
    pthread_mutex_lock(&w->mutex);
    int last = --w->references == 0;
    pthread_mutex_unlock(&w->mutex);
    if (last) {
        close(w->input); close(w->output);
        pthread_mutex_destroy(&w->mutex); free(w);
    }
}
static void vox_h2_wake_close(void *handle) {
    if (!handle) return;
    vox_h2_wake *w = handle;
    pthread_mutex_lock(&w->mutex); w->closed = 1; pthread_mutex_unlock(&w->mutex);
    vox_h2_wake_signal(handle);
    vox_h2_wake_release(handle);
}
// Consumes one retained reference; descriptors stay alive through poll/drain.
static int vox_h2_wake_wait(void *handle, int socket, int milliseconds) {
    vox_h2_wake *w = handle;
    struct pollfd fds[2] = {{socket, POLLIN, 0}, {w->input, POLLIN, 0}};
    int status = poll(fds, 2, milliseconds);
    if (status < 0 && errno == EINTR) status = 0;
    if (fds[1].revents & POLLIN) {
        unsigned char bytes[128];
        while (read(w->input, bytes, sizeof(bytes)) > 0) {}
    }
    pthread_mutex_lock(&w->mutex);
    if (w->closed) status = -2;
    pthread_mutex_unlock(&w->mutex);
    vox_h2_wake_release(handle);
    return status;
}
#else
static void *vox_h2_wake_create(void) { return NULL; }
static void *vox_h2_wake_retain(void *w) { return w; }
static void vox_h2_wake_signal(void *w) { (void)w; }
static void vox_h2_wake_close(void *w) { (void)w; }
static int vox_h2_wake_wait(void *w, int socket, int ms) { return -1; }
#endif
#endif
