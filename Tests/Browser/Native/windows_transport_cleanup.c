// Exercise Windows request ownership on every host, without a resolver/server.
#include "../../../platform/curl_api.h"
#include "../../../browsernet/request_scope.h"
#include <assert.h>

static VoxCurlApi observed_api;
static int cleanups;
static int fail_easy;
static pthread_t request_thread;
static CURLMcode observe_cleanup(CURLM *multi) {
    assert(pthread_equal(request_thread, pthread_self()));
    ++cleanups;
    return curl_multi_cleanup(multi);
}
static CURL *observe_easy_init(void) {
    return fail_easy ? NULL : curl_easy_init();
}
static const VoxCurlApi *request_api(void) { return &observed_api; }
#define vox_curl_api request_api
#ifndef _WIN32
#define _WIN32
#endif
#include "../../../browsernet/cancellable_transport.h"
#undef vox_curl_api

static size_t receive(void *data, size_t size, size_t count, void *owner) {
    (void)data; (void)owner;
    return size * count;
}
static void *run_requests(void *unused) {
    (void)unused;
    request_thread = pthread_self();
    void *scope = vox_resource_scope_create();
    assert(scope);
    for (int attempt = 0; attempt < 3; ++attempt) {
        fail_easy = attempt == 1;
        char error[CURL_ERROR_SIZE] = {0};
        int protocol = -1;
        int code = vox_resource_curl_fetch("unsupported-vox-fixture://local", "", "", "Vox test",
            NULL, NULL, scope, receive, receive, error, false, &protocol);
        assert(code == (fail_easy ? CURLE_OUT_OF_MEMORY : CURLE_UNSUPPORTED_PROTOCOL));
        // Both failed initialization and completed transfers retire their native
        // cache here. A TLS destructor would defer cleanup until thread exit.
        assert(cleanups == attempt + 1);
    }
    vox_resource_scope_release(scope);
    return NULL;
}
int main(void) {
    observed_api = *vox_curl_api();
    observed_api.multi_cleanup = observe_cleanup;
    observed_api.easy_init = observe_easy_init;
    pthread_t worker;
    assert(!pthread_create(&worker, NULL, run_requests, NULL));
    assert(!pthread_join(worker, NULL));
    assert(cleanups == 3);
    return 0;
}
