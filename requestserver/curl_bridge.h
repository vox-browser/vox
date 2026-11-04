/* Native ABI adaptation for the translated RequestServer curl callbacks. */
#ifndef VOX_REQUESTSERVER_CURL_BRIDGE_H
#define VOX_REQUESTSERVER_CURL_BRIDGE_H
#include <curl/curl.h>
#include <stdlib.h>
typedef struct {
    __typeof__(curl_global_init)* global_init;
    __typeof__(curl_multi_init)* multi_init;
    __typeof__(curl_multi_cleanup)* multi_cleanup;
    __typeof__(curl_multi_socket_action)* multi_socket_action;
    __typeof__(curl_multi_add_handle)* multi_add_handle;
    __typeof__(curl_multi_remove_handle)* multi_remove_handle;
    __typeof__(curl_multi_setopt)* multi_setopt;
    __typeof__(curl_multi_info_read)* multi_info_read;
    __typeof__(curl_easy_init)* easy_init;
    __typeof__(curl_easy_cleanup)* easy_cleanup;
    __typeof__(curl_easy_pause)* easy_pause;
    __typeof__(curl_easy_setopt)* easy_setopt;
    __typeof__(curl_easy_getinfo)* easy_getinfo;
    __typeof__(curl_slist_append)* slist_append;
    __typeof__(curl_slist_free_all)* slist_free_all;
} VoxCurlApi;
#ifdef __APPLE__
#include <dlfcn.h>
#include <pthread.h>
#include <stdio.h>
// Documents, subresources and images load through browsernet; only script
// fetches, workers and web fonts use curl. Linking it would map libcurl with
// OpenSSL, HTTP/2, HTTP/3 and compression libraries into every launch (and
// into the allocator restart's first image), so resolve it on first use.
// Production rpaths name the same vcpkg library the linker selected; a test
// binary without them uses the system library that -lcurl linked before.
static VoxCurlApi vox_curl_loaded_api;
static void vox_curl_load_api(void) {
    void* library = dlopen("@rpath/libcurl.4.dylib", RTLD_NOW | RTLD_LOCAL);
    if (!library) library = dlopen("/usr/lib/libcurl.4.dylib", RTLD_NOW | RTLD_LOCAL);
    if (!library) {
        fprintf(stderr, "Vox: cannot load libcurl: %s\n", dlerror());
        abort();
    }
#define VOX_CURL_RESOLVE(field, symbol) \
    if (!(*(void**)&vox_curl_loaded_api.field = dlsym(library, #symbol))) { \
        fprintf(stderr, "Vox: libcurl lacks %s\n", #symbol); \
        abort(); \
    }
    VOX_CURL_RESOLVE(global_init, curl_global_init)
    VOX_CURL_RESOLVE(multi_init, curl_multi_init)
    VOX_CURL_RESOLVE(multi_cleanup, curl_multi_cleanup)
    VOX_CURL_RESOLVE(multi_socket_action, curl_multi_socket_action)
    VOX_CURL_RESOLVE(multi_add_handle, curl_multi_add_handle)
    VOX_CURL_RESOLVE(multi_remove_handle, curl_multi_remove_handle)
    VOX_CURL_RESOLVE(multi_setopt, curl_multi_setopt)
    VOX_CURL_RESOLVE(multi_info_read, curl_multi_info_read)
    VOX_CURL_RESOLVE(easy_init, curl_easy_init)
    VOX_CURL_RESOLVE(easy_cleanup, curl_easy_cleanup)
    VOX_CURL_RESOLVE(easy_pause, curl_easy_pause)
    VOX_CURL_RESOLVE(easy_setopt, curl_easy_setopt)
    VOX_CURL_RESOLVE(easy_getinfo, curl_easy_getinfo)
    VOX_CURL_RESOLVE(slist_append, curl_slist_append)
    VOX_CURL_RESOLVE(slist_free_all, curl_slist_free_all)
#undef VOX_CURL_RESOLVE
}
static const VoxCurlApi* vox_curl_api(void) {
    static pthread_once_t once = PTHREAD_ONCE_INIT;
    pthread_once(&once, vox_curl_load_api);
    return &vox_curl_loaded_api;
}
// Test observation: whether a caller has made this process resolve libcurl.
static int vox_curl_library_loaded(void) { return vox_curl_loaded_api.global_init != NULL; }
#else
static const VoxCurlApi vox_curl_linked_api = {
    curl_global_init, curl_multi_init, curl_multi_cleanup, curl_multi_socket_action,
    curl_multi_add_handle, curl_multi_remove_handle, curl_multi_setopt, curl_multi_info_read,
    curl_easy_init, curl_easy_cleanup, curl_easy_pause, curl_easy_setopt, curl_easy_getinfo,
    curl_slist_append, curl_slist_free_all,
};
static const VoxCurlApi* vox_curl_api(void) { return &vox_curl_linked_api; }
static int vox_curl_library_loaded(void) { return 1; }
#endif
static int vox_curl_global_init(long flags) { return vox_curl_api()->global_init(flags); }
static void* vox_curl_multi_init(void) { return vox_curl_api()->multi_init(); }
static int vox_curl_multi_cleanup(void* handle) { return vox_curl_api()->multi_cleanup(handle); }
static int vox_curl_multi_socket_action(void* handle, int socket, int events, int* running) { return vox_curl_api()->multi_socket_action(handle, socket, events, running); }
static int vox_curl_multi_add_handle(void* multi, void* easy) { return vox_curl_api()->multi_add_handle(multi, easy); }
static int vox_curl_multi_remove_handle(void* multi, void* easy) { return vox_curl_api()->multi_remove_handle(multi, easy); }
static void* vox_curl_easy_init(void) { return vox_curl_api()->easy_init(); }
static void vox_curl_easy_cleanup(void* handle) { vox_curl_api()->easy_cleanup(handle); }
static int vox_curl_easy_pause(void* handle, int flags) { return vox_curl_api()->easy_pause(handle, flags); }
static void* vox_curl_slist_append(void* list, const char* value) { return vox_curl_api()->slist_append(list, value); }
static void vox_curl_slist_free_all(void* list) { vox_curl_api()->slist_free_all(list); }
static int vox_curl_setopt_long(void* handle, int option, long value) { return vox_curl_api()->easy_setopt(handle, option, value); }
static int vox_curl_setopt_pointer(void* handle, int option, void* value) { return vox_curl_api()->easy_setopt(handle, option, value); }
static int vox_curl_setopt_write(void* handle, int option, size_t (*callback)(void*, size_t, size_t, void*)) { return vox_curl_api()->easy_setopt(handle, option, callback); }
static int vox_curl_multi_setopt_pointer(void* handle, int option, void* value) { return vox_curl_api()->multi_setopt(handle, option, value); }
static int vox_curl_multi_setopt_long(void* handle, int option, long value) { return vox_curl_api()->multi_setopt(handle, option, value); }
static int vox_curl_multi_setopt_socket(void* handle, int (*callback)(void*, int, int, void*, void*)) { return vox_curl_api()->multi_setopt(handle, CURLMOPT_SOCKETFUNCTION, callback); }
static int vox_curl_multi_setopt_timer(void* handle, int (*callback)(void*, long, void*)) { return vox_curl_api()->multi_setopt(handle, CURLMOPT_TIMERFUNCTION, callback); }
static void* vox_curl_next_completion(void* multi, int* result) {
    int remaining;
    CURLMsg* message;
    while ((message = vox_curl_api()->multi_info_read(multi, &remaining))) {
        if (message->msg != CURLMSG_DONE) continue;
        void* request = NULL;
        if (vox_curl_api()->easy_getinfo(message->easy_handle, CURLINFO_PRIVATE, &request) != CURLE_OK) abort();
        *result = message->data.result;
        return request;
    }
    return NULL;
}
static long vox_curl_status(void* handle) { long value = 0; vox_curl_api()->easy_getinfo(handle, CURLINFO_RESPONSE_CODE, &value); return value; }
static long vox_curl_version(void* handle) { long value = 0; vox_curl_api()->easy_getinfo(handle, CURLINFO_HTTP_VERSION, &value); return value; }
static long long vox_curl_time(void* handle, int option) { curl_off_t value = 0; vox_curl_api()->easy_getinfo(handle, option, &value); return value; }
static long long vox_curl_queue_time(void* handle) {
#if LIBCURL_VERSION_NUM >= 0x080600
    return vox_curl_time(handle, CURLINFO_QUEUE_TIME_T);
#else
    /* Older macOS SDK curl cannot expose the source's queue timestamp. */
    return 0;
#endif
}
#ifdef __APPLE__
#include <CoreFoundation/CoreFoundation.h>
#include <dispatch/dispatch.h>
#include <pthread.h>
#include <unistd.h>
#include <fcntl.h>
// Dispatch sources keep delivering readiness while curl advances a partial
// SOCKS/TLS record. Suspend each delivered source until curl updates interest,
// and process its notification on the owning CF loop, never a dispatch worker.
typedef struct {
    void* owner;
    int socket;
    int watched_socket;
    void (*activate)(void*, int, int);
    CFRunLoopRef loop;
    CFRunLoopSourceRef source;
    dispatch_source_t read_source;
    dispatch_source_t write_source;
    pthread_mutex_t mutex;
    unsigned references;
    int interest;
    int pending;
    bool valid;
    bool read_suspended;
    bool write_suspended;
} VoxCurlSocketContext;
static void vox_curl_socket_retain(VoxCurlSocketContext* state) {
    pthread_mutex_lock(&state->mutex);
    ++state->references;
    pthread_mutex_unlock(&state->mutex);
}
static void vox_curl_socket_release(VoxCurlSocketContext* state) {
    pthread_mutex_lock(&state->mutex);
    bool dispose = --state->references == 0;
    pthread_mutex_unlock(&state->mutex);
    if (!dispose) return;
#if !__has_feature(objc_arc)
    dispatch_release(state->read_source);
    dispatch_release(state->write_source);
#endif
    state->read_source = NULL;
    state->write_source = NULL;
    close(state->watched_socket);
    CFRelease(state->loop);
    pthread_mutex_destroy(&state->mutex);
    free(state);
}
static const void* vox_curl_source_retain(const void* context) {
    vox_curl_socket_retain((VoxCurlSocketContext*)context);
    return context;
}
static void vox_curl_source_release(const void* context) {
    vox_curl_socket_release((VoxCurlSocketContext*)context);
}
static void vox_curl_socket_deliver(void* context) {
    VoxCurlSocketContext* state = context;
    vox_curl_socket_retain(state);
    pthread_mutex_lock(&state->mutex);
    int flags = state->pending & state->interest;
    state->pending = 0;
    bool valid = state->valid;
    pthread_mutex_unlock(&state->mutex);
    if (valid && flags) state->activate(state->owner, state->socket, flags);
    vox_curl_socket_release(state);
}
static void vox_curl_socket_notify(VoxCurlSocketContext* state, int flag) {
    pthread_mutex_lock(&state->mutex);
    if (!state->valid || !(state->interest & flag)) {
        pthread_mutex_unlock(&state->mutex);
        return;
    }
    if (flag == CURL_POLL_IN && !state->read_suspended) {
        dispatch_suspend(state->read_source);
        state->read_suspended = true;
    }
    if (flag == CURL_POLL_OUT && !state->write_suspended) {
        dispatch_suspend(state->write_source);
        state->write_suspended = true;
    }
    state->pending |= flag;
    CFRunLoopSourceRef source = (CFRunLoopSourceRef)CFRetain(state->source);
    pthread_mutex_unlock(&state->mutex);
    CFRunLoopSourceSignal(source);
    CFRunLoopWakeUp(state->loop);
    CFRelease(source);
}
static void vox_curl_socket_read(void* context) { vox_curl_socket_notify(context, CURL_POLL_IN); }
static void vox_curl_socket_write(void* context) { vox_curl_socket_notify(context, CURL_POLL_OUT); }
static void vox_curl_socket_cancelled(void* context) { vox_curl_socket_release(context); }
static void* vox_curl_socket_create(void* owner, int socket, void (*activate)(void*, int, int)) {
    VoxCurlSocketContext* state = calloc(1, sizeof(*state));
    if (!state) abort();
    state->owner = owner;
    state->socket = socket;
    // Own a duplicate until both dispatch cancellation handlers finish. curl
    // can close and reuse its original descriptor before cancellation arrives.
    state->watched_socket = fcntl(socket, F_DUPFD_CLOEXEC, 0);
    if (state->watched_socket < 0) abort();
    state->activate = activate;
    state->loop = (CFRunLoopRef)CFRetain(CFRunLoopGetCurrent());
    pthread_mutex_init(&state->mutex, NULL);
    state->references = 3; // Owner and the two dispatch cancellation handlers.
    state->valid = true;
    state->read_suspended = state->write_suspended = true;
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    state->read_source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, state->watched_socket, 0, queue);
    state->write_source = dispatch_source_create(DISPATCH_SOURCE_TYPE_WRITE, state->watched_socket, 0, queue);
    if (!state->read_source || !state->write_source) abort();
    dispatch_set_context(state->read_source, state);
    dispatch_set_context(state->write_source, state);
    dispatch_source_set_event_handler_f(state->read_source, vox_curl_socket_read);
    dispatch_source_set_event_handler_f(state->write_source, vox_curl_socket_write);
    dispatch_source_set_cancel_handler_f(state->read_source, vox_curl_socket_cancelled);
    dispatch_source_set_cancel_handler_f(state->write_source, vox_curl_socket_cancelled);
    CFRunLoopSourceContext context = { 0, state, vox_curl_source_retain, vox_curl_source_release,
        NULL, NULL, NULL, NULL, NULL, vox_curl_socket_deliver };
    state->source = CFRunLoopSourceCreate(NULL, 0, &context);
    if (!state->source) abort();
    CFRunLoopAddSource(state->loop, state->source, kCFRunLoopCommonModes);
    return state;
}
static void vox_curl_socket_set_enabled(void* value, int flags) {
    VoxCurlSocketContext* state = value;
    pthread_mutex_lock(&state->mutex);
    if (state->valid) {
        state->interest = flags;
        state->pending &= flags;
        bool read_suspended = !(flags & CURL_POLL_IN);
        bool write_suspended = !(flags & CURL_POLL_OUT);
        if (read_suspended != state->read_suspended) {
            if (read_suspended) dispatch_suspend(state->read_source); else dispatch_resume(state->read_source);
            state->read_suspended = read_suspended;
        }
        if (write_suspended != state->write_suspended) {
            if (write_suspended) dispatch_suspend(state->write_source); else dispatch_resume(state->write_source);
            state->write_suspended = write_suspended;
        }
    }
    pthread_mutex_unlock(&state->mutex);
}
static void vox_curl_socket_destroy(void* value) {
    VoxCurlSocketContext* state = value;
    pthread_mutex_lock(&state->mutex);
    state->valid = false;
    state->interest = state->pending = 0;
    CFRunLoopSourceRef source = state->source;
    state->source = NULL;
    if (state->read_suspended) { dispatch_resume(state->read_source); state->read_suspended = false; }
    if (state->write_suspended) { dispatch_resume(state->write_source); state->write_suspended = false; }
    dispatch_source_cancel(state->read_source);
    dispatch_source_cancel(state->write_source);
    pthread_mutex_unlock(&state->mutex);
    CFRunLoopSourceInvalidate(source);
    CFRelease(source);
    vox_curl_socket_release(state);
}
#elif defined(__linux__)
#include <glib-unix.h>
#include "../platform/linux_event_context.h"
typedef struct {
    void *owner;
    int socket;
    void (*activate)(void *, int, int);
    GSource *source;
} VoxCurlSocketContext;
static gboolean vox_curl_socket_callback(gint fd, GIOCondition condition, gpointer context) {
    VoxCurlSocketContext state = *(VoxCurlSocketContext *)context;
    int flags = 0;
    if (condition & G_IO_IN) flags |= CURL_CSELECT_IN;
    if (condition & G_IO_OUT) flags |= CURL_CSELECT_OUT;
    if (condition & (G_IO_ERR | G_IO_HUP | G_IO_NVAL)) flags |= CURL_CSELECT_ERR;
    state.activate(state.owner, fd, flags);
    return G_SOURCE_CONTINUE;
}
static void *vox_curl_socket_create(void *owner, int socket, void (*activate)(void *, int, int)) {
    VoxCurlSocketContext *state = calloc(1, sizeof(*state));
    if (!state) abort();
    state->owner = owner; state->socket = socket; state->activate = activate;
    return state;
}
static void vox_curl_socket_set_enabled(void *descriptor, int flags) {
    VoxCurlSocketContext *state = descriptor;
    if (state->source) { g_source_destroy(state->source); g_source_unref(state->source); state->source = NULL; }
    if (!flags) return;
    GIOCondition condition = G_IO_ERR | G_IO_HUP | G_IO_NVAL;
    if (flags & CURL_POLL_IN) condition |= G_IO_IN;
    if (flags & CURL_POLL_OUT) condition |= G_IO_OUT;
    state->source = g_unix_fd_source_new(state->socket, condition);
    g_source_set_callback(state->source, G_SOURCE_FUNC(vox_curl_socket_callback), state, NULL);
    g_source_attach(state->source, libweb_v_thread_event_context());
}
static void vox_curl_socket_destroy(void *descriptor) {
    VoxCurlSocketContext *state = descriptor;
    if (state->source) { g_source_destroy(state->source); g_source_unref(state->source); }
    free(state);
}
#endif
#endif
