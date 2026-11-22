/* Shared libcurl ABI for native Fetch and cancellable resource workers. */
#ifndef VOX_PLATFORM_CURL_API_H
#define VOX_PLATFORM_CURL_API_H
#include <curl/curl.h>
#include <stdlib.h>
#include <pthread.h>
#include "native_state.h"
typedef struct {
    __typeof__(curl_global_init)* global_init;
    __typeof__(curl_multi_init)* multi_init;
    __typeof__(curl_multi_cleanup)* multi_cleanup;
    __typeof__(curl_multi_socket_action)* multi_socket_action;
    __typeof__(curl_multi_perform)* multi_perform;
    __typeof__(curl_multi_wait)* multi_wait;
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
// Keep libcurl lazy. Both native Fetch and cancellable browser resource
// requests use macOS's system library, including its TLS trust integration.
VOX_NATIVE_STATE VoxCurlApi vox_curl_loaded_api;
VOX_NATIVE_STATE pthread_once_t vox_curl_load_once VOX_NATIVE_STATE_INIT(PTHREAD_ONCE_INIT);
static void vox_curl_load_api(void) {
    void* library = dlopen("/usr/lib/libcurl.4.dylib", RTLD_NOW | RTLD_LOCAL);
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
    VOX_CURL_RESOLVE(multi_perform, curl_multi_perform)
    VOX_CURL_RESOLVE(multi_wait, curl_multi_wait)
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
    pthread_once(&vox_curl_load_once, vox_curl_load_api);
    return &vox_curl_loaded_api;
}
// Test observation: whether a caller has made this process resolve libcurl.
static int vox_curl_library_loaded(void) { return vox_curl_loaded_api.global_init != NULL; }
#else
static const VoxCurlApi vox_curl_linked_api = {
    curl_global_init, curl_multi_init, curl_multi_cleanup, curl_multi_socket_action,
    curl_multi_perform, curl_multi_wait,
    curl_multi_add_handle, curl_multi_remove_handle, curl_multi_setopt, curl_multi_info_read,
    curl_easy_init, curl_easy_cleanup, curl_easy_pause, curl_easy_setopt, curl_easy_getinfo,
    curl_slist_append, curl_slist_free_all,
};
static const VoxCurlApi* vox_curl_api(void) { return &vox_curl_linked_api; }
static int vox_curl_library_loaded(void) { return 1; }
#endif
VOX_NATIVE_STATE pthread_once_t vox_curl_global_once VOX_NATIVE_STATE_INIT(PTHREAD_ONCE_INIT);
VOX_NATIVE_STATE int vox_curl_global_result;
static void vox_curl_initialize_once(void) {
    vox_curl_global_result = vox_curl_api()->global_init(CURL_GLOBAL_ALL);
}
// All callers request CURL_GLOBAL_ALL. Complete global initialization once
// before any worker creates an easy/multi handle, including on older libcurl.
static int vox_curl_global_init(long flags) {
    (void)flags;
    pthread_once(&vox_curl_global_once, vox_curl_initialize_once);
    return vox_curl_global_result;
}
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
// Configure a fresh handle's server trust without changing peer/host checks.
// An explicit bundle remains authoritative, including an invalid bundle path.
static CURLcode vox_curl_server_trust(void *handle, const char *bundle) {
    const VoxCurlApi *api = vox_curl_api();
    if (bundle && bundle[0]) return api->easy_setopt(handle, CURLOPT_CAINFO, bundle);
#ifdef _WIN32
    CURLcode result = api->easy_setopt(handle, CURLOPT_SSL_OPTIONS, (long)CURLSSLOPT_NATIVE_CA);
    if (result != CURLE_OK) return result;
    // The MinGW libcurl build's Unix-style defaults need not exist in a
    // portable Windows deployment. Use Windows roots instead of those files.
    result = api->easy_setopt(handle, CURLOPT_CAINFO, (char *)NULL);
    if (result != CURLE_OK) return result;
    return api->easy_setopt(handle, CURLOPT_CAPATH, (char *)NULL);
#else
    return CURLE_OK;
#endif
}
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
static long vox_curl_num_connects(void* handle) { long value = 0; vox_curl_api()->easy_getinfo(handle, CURLINFO_NUM_CONNECTS, &value); return value; }
static long long vox_curl_time(void* handle, int option) { curl_off_t value = 0; vox_curl_api()->easy_getinfo(handle, option, &value); return value; }
static long long vox_curl_queue_time(void* handle) {
#if LIBCURL_VERSION_NUM >= 0x080600
    return vox_curl_time(handle, CURLINFO_QUEUE_TIME_T);
#else
    /* Older libcurl versions cannot expose the source's queue timestamp. */
    (void)handle;
    return 0;
#endif
}
#endif
