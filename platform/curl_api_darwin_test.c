// Compile without -lcurl: the transport must stay lazy and use the system ABI
// even when a Homebrew curl is installed on this host.
#include "curl_api.h"
#include <assert.h>
#include <string.h>

static void check_system_provider(void *symbol) {
    Dl_info provider = {0};
    assert(dladdr(symbol, &provider));
    assert(strcmp(provider.dli_fname, "/usr/lib/libcurl.4.dylib") == 0);
}

int main(void) {
    assert(!vox_curl_library_loaded());
    assert(vox_curl_global_init(CURL_GLOBAL_ALL) == CURLE_OK);
    assert(vox_curl_library_loaded());
    const VoxCurlApi *api = vox_curl_api();
    check_system_provider((void *)api->global_init);
    check_system_provider((void *)api->easy_init);
    check_system_provider((void *)api->multi_init);
    void *easy = vox_curl_easy_init();
    void *multi = vox_curl_multi_init();
    assert(easy && multi);
    assert(vox_curl_setopt_long(easy, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_2TLS) == CURLE_OK);
    assert(vox_curl_multi_add_handle(multi, easy) == CURLM_OK);
    assert(vox_curl_multi_remove_handle(multi, easy) == CURLM_OK);
    vox_curl_easy_cleanup(easy);
    assert(vox_curl_multi_cleanup(multi) == CURLM_OK);
    return 0;
}
