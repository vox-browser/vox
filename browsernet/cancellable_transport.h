#ifndef VOX_BROWSER_CANCELLABLE_TRANSPORT_H
#define VOX_BROWSER_CANCELLABLE_TRANSPORT_H
#include "../platform/curl_api.h"
#include "request_scope.h"
#include <string.h>

typedef struct {
    long request_protocol;
} VoxResourceTransfer;

// CURLINFO_HTTP_VERSION can still be zero if the peer never sent response
// headers. libcurl's outbound header record identifies the request version
// after negotiation, including on an already pooled connection. Consume it
// privately: enabling this callback must never print request headers/cookies.
static int vox_resource_curl_debug(CURL *easy, curl_infotype type, char *data,
        size_t length, void *owner) {
    (void)easy;
    if (type != CURLINFO_HEADER_OUT || length < 4 || memcmp(data, "GET ", 4)) return 0;
    const char *end = memchr(data, '\n', length);
    if (!end) return 0;
    size_t line_length = end - data;
    if (line_length && data[line_length - 1] == '\r') --line_length;
    VoxResourceTransfer *transfer = owner;
    if (line_length >= 7 && !memcmp(data + line_length - 7, " HTTP/2", 7)) {
        transfer->request_protocol = CURL_HTTP_VERSION_2_0;
    } else if (line_length >= 9 && !memcmp(data + line_length - 9, " HTTP/1.1", 9)) {
        transfer->request_protocol = CURL_HTTP_VERSION_1_1;
    }
    return 0;
}

// A worker reuses its multi handle's connection cache for its subsequent jobs.
// Windows pthread destructors run under the DLL loader lock. curl cleanup can
// join a resolver thread, whose DLL initialization needs that lock, so Windows
// transfers own and release their handles before returning to the caller.
#ifndef _WIN32
// No native event-loop callback or translated DOM/Fetch object crosses threads.
VOX_NATIVE_STATE pthread_key_t vox_resource_curl_worker_key;
VOX_NATIVE_STATE pthread_once_t vox_resource_curl_worker_once VOX_NATIVE_STATE_INIT(PTHREAD_ONCE_INIT);
static void vox_resource_curl_worker_destroy(void *multi) {
    if (multi) vox_curl_api()->multi_cleanup(multi);
}
static void vox_resource_curl_worker_initialize(void) {
    if (pthread_key_create(&vox_resource_curl_worker_key, vox_resource_curl_worker_destroy)) abort();
}
static void *vox_resource_curl_worker(void) {
    pthread_once(&vox_resource_curl_worker_once, vox_resource_curl_worker_initialize);
    void *multi = pthread_getspecific(vox_resource_curl_worker_key);
    if (!multi) {
        multi = vox_curl_api()->multi_init();
        if (!multi) return NULL;
        // Bound each worker's idle connections too. Active transfers are
        // governed by the shared resource service's permit, not this cache.
        if (vox_curl_api()->multi_setopt(multi, CURLMOPT_MAXCONNECTS, 6L) != CURLM_OK
            || pthread_setspecific(vox_resource_curl_worker_key, multi)) {
            vox_curl_api()->multi_cleanup(multi);
            return NULL;
        }
    }
    return multi;
}
#endif

static int vox_resource_curl_fetch(const char *url, const char *proxy,
        const char *ca_bundle, const char *user_agent, void *headers,
        void *owner, void *scope,
        size_t (*receive_header)(void *, size_t, size_t, void *),
        size_t (*receive_body)(void *, size_t, size_t, void *), char *error_buffer,
        bool enable_http2, int *protocol) {
    *protocol = 0;
    if (vox_resource_scope_cancelled(scope)) return CURLE_ABORTED_BY_CALLBACK;
    CURLcode result = vox_curl_global_init(CURL_GLOBAL_ALL);
    if (result != CURLE_OK) return result;
    const VoxCurlApi *api = vox_curl_api();
#ifdef _WIN32
    void *multi = api->multi_init();
#else
    void *multi = vox_resource_curl_worker();
#endif
    void *easy = api->easy_init();
    if (!multi || !easy) {
        if (easy) api->easy_cleanup(easy);
#ifdef _WIN32
        if (multi) api->multi_cleanup(multi);
#endif
        return CURLE_OUT_OF_MEMORY;
    }
    bool attached = false;
    VoxResourceTransfer transfer = {0};
#define VOX_RESOURCE_OPTION(option, value) \
    do { result = api->easy_setopt(easy, option, value); if (result != CURLE_OK) goto done; } while (0)
    VOX_RESOURCE_OPTION(CURLOPT_URL, url);
    VOX_RESOURCE_OPTION(CURLOPT_PROXY, proxy);
    // Proxy selection (including bypasses) has already been made by V.
    VOX_RESOURCE_OPTION(CURLOPT_NOPROXY, "");
    VOX_RESOURCE_OPTION(CURLOPT_USERAGENT, user_agent);
    VOX_RESOURCE_OPTION(CURLOPT_HTTPHEADER, headers);
    // Multi I/O is cancellable between polls. A libcurl built with a
    // synchronous resolver can still block inside DNS; use its threaded or
    // c-ares resolver for cancellation during name resolution as well.
    VOX_RESOURCE_OPTION(CURLOPT_NOSIGNAL, 1L);
    VOX_RESOURCE_OPTION(CURLOPT_FOLLOWLOCATION, 0L);
    VOX_RESOURCE_OPTION(CURLOPT_SSL_VERIFYPEER, 1L);
    VOX_RESOURCE_OPTION(CURLOPT_SSL_VERIFYHOST, 2L);
    result = vox_curl_server_trust(easy, ca_bundle);
    if (result != CURLE_OK) goto done;
    VOX_RESOURCE_OPTION(CURLOPT_ACCEPT_ENCODING, "");
    VOX_RESOURCE_OPTION(CURLOPT_HTTP_VERSION, enable_http2
        ? (long)CURL_HTTP_VERSION_2TLS : (long)CURL_HTTP_VERSION_1_1);
    VOX_RESOURCE_OPTION(CURLOPT_CONNECTTIMEOUT_MS, 10000L);
    VOX_RESOURCE_OPTION(CURLOPT_LOW_SPEED_LIMIT, 1L);
    VOX_RESOURCE_OPTION(CURLOPT_LOW_SPEED_TIME, 10L);
    VOX_RESOURCE_OPTION(CURLOPT_SUPPRESS_CONNECT_HEADERS, 1L);
    VOX_RESOURCE_OPTION(CURLOPT_ERRORBUFFER, error_buffer);
    VOX_RESOURCE_OPTION(CURLOPT_DEBUGFUNCTION, vox_resource_curl_debug);
    VOX_RESOURCE_OPTION(CURLOPT_DEBUGDATA, &transfer);
    VOX_RESOURCE_OPTION(CURLOPT_VERBOSE, 1L);
    VOX_RESOURCE_OPTION(CURLOPT_HEADERFUNCTION, receive_header);
    VOX_RESOURCE_OPTION(CURLOPT_HEADERDATA, owner);
    VOX_RESOURCE_OPTION(CURLOPT_WRITEFUNCTION, receive_body);
    VOX_RESOURCE_OPTION(CURLOPT_WRITEDATA, owner);
#undef VOX_RESOURCE_OPTION
    if (api->multi_add_handle(multi, easy) != CURLM_OK) { result = CURLE_FAILED_INIT; goto done; }
    attached = true;
    for (;;) {
        // Remove the easy handle on its owning worker even if an origin has
        // stopped sending headers/body. A body-progress callback alone cannot
        // cancel that state. No slot is released before removal and cleanup.
        if (vox_resource_scope_cancelled(scope)) { result = CURLE_ABORTED_BY_CALLBACK; break; }
        int running = 0;
        if (api->multi_perform(multi, &running) != CURLM_OK) { result = CURLE_RECV_ERROR; break; }
        int remaining;
        CURLMsg *message;
        bool complete = false;
        while ((message = api->multi_info_read(multi, &remaining))) {
            if (message->msg == CURLMSG_DONE && message->easy_handle == easy) {
                result = message->data.result;
                complete = true;
            }
        }
        if (complete) break;
        if (!running) { result = CURLE_RECV_ERROR; break; }
        int ready = 0;
        if (api->multi_wait(multi, NULL, 0, 25, &ready) != CURLM_OK) { result = CURLE_RECV_ERROR; break; }
        // Some resolver/backoff states have no descriptor. multi_wait then
        // returns immediately; wait on cancellation instead of busy-spinning.
        if (!ready) vox_resource_scope_wait(scope, 10000000LL);
    }
done:
    {
        long version = 0;
        api->easy_getinfo(easy, CURLINFO_HTTP_VERSION, &version);
        *protocol = (int)(version ? version : transfer.request_protocol);
    }
    if (attached) api->multi_remove_handle(multi, easy);
    api->easy_cleanup(easy);
#ifdef _WIN32
    api->multi_cleanup(multi);
#endif
    return result;
}
#endif
