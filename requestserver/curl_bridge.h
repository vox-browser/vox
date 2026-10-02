/* Native ABI adaptation for the translated RequestServer curl callbacks. */
#ifndef VOX_REQUESTSERVER_CURL_BRIDGE_H
#define VOX_REQUESTSERVER_CURL_BRIDGE_H
#include <curl/curl.h>
#include <stdlib.h>
static int vox_curl_setopt_long(void* handle, int option, long value) { return curl_easy_setopt(handle, option, value); }
static int vox_curl_setopt_pointer(void* handle, int option, void* value) { return curl_easy_setopt(handle, option, value); }
static int vox_curl_setopt_write(void* handle, int option, size_t (*callback)(void*, size_t, size_t, void*)) { return curl_easy_setopt(handle, option, callback); }
static int vox_curl_multi_setopt_pointer(void* handle, int option, void* value) { return curl_multi_setopt(handle, option, value); }
static int vox_curl_multi_setopt_socket(void* handle, int (*callback)(void*, int, int, void*, void*)) { return curl_multi_setopt(handle, CURLMOPT_SOCKETFUNCTION, callback); }
static int vox_curl_multi_setopt_timer(void* handle, int (*callback)(void*, long, void*)) { return curl_multi_setopt(handle, CURLMOPT_TIMERFUNCTION, callback); }
static void* vox_curl_next_completion(void* multi, int* result) {
    int remaining;
    CURLMsg* message;
    while ((message = curl_multi_info_read(multi, &remaining))) {
        if (message->msg != CURLMSG_DONE) continue;
        void* request = NULL;
        if (curl_easy_getinfo(message->easy_handle, CURLINFO_PRIVATE, &request) != CURLE_OK) abort();
        *result = message->data.result;
        return request;
    }
    return NULL;
}
static long vox_curl_status(void* handle) { long value = 0; curl_easy_getinfo(handle, CURLINFO_RESPONSE_CODE, &value); return value; }
static long vox_curl_version(void* handle) { long value = 0; curl_easy_getinfo(handle, CURLINFO_HTTP_VERSION, &value); return value; }
static long long vox_curl_time(void* handle, int option) { curl_off_t value = 0; curl_easy_getinfo(handle, option, &value); return value; }
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
typedef struct {
    void* owner;
    int socket;
    void (*activate)(void*, int, int);
} VoxCurlSocketContext;
static void vox_curl_socket_release(const void* context) { free((void*)context); }
static void vox_curl_socket_callback(CFFileDescriptorRef descriptor, CFOptionFlags flags, void* context) {
    VoxCurlSocketContext state = *(VoxCurlSocketContext*)context;
    CFRetain(descriptor);
    state.activate(state.owner, state.socket, (int)flags);
    CFRelease(descriptor);
}
static void* vox_curl_socket_create(void* owner, int socket, void (*activate)(void*, int, int)) {
    VoxCurlSocketContext* state = malloc(sizeof(*state));
    if (!state) abort();
    *state = (VoxCurlSocketContext){ owner, socket, activate };
    CFFileDescriptorContext context = { 0, state, NULL, vox_curl_socket_release, NULL };
    CFFileDescriptorRef descriptor = CFFileDescriptorCreate(NULL, socket, false, vox_curl_socket_callback, &context);
    if (!descriptor) abort();
    CFRunLoopSourceRef source = CFFileDescriptorCreateRunLoopSource(NULL, descriptor, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopCommonModes);
    CFRelease(source);
    return (void*)descriptor;
}
static void vox_curl_socket_set_enabled(void* value, int flags) {
    CFFileDescriptorRef descriptor = value;
    CFFileDescriptorDisableCallBacks(descriptor, kCFFileDescriptorReadCallBack | kCFFileDescriptorWriteCallBack);
    if (flags) CFFileDescriptorEnableCallBacks(descriptor, flags);
}
static void vox_curl_socket_destroy(void* descriptor) { CFFileDescriptorInvalidate(descriptor); CFRelease(descriptor); }
#endif
#endif
