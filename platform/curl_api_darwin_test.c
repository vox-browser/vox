// Compile without -lcurl: the transport must stay lazy. Run it twice, normally
// and with VOX_SYSTEM_LIBCURL=1:
//   clang -I platform -o curl_api_test platform/curl_api_darwin_test.c && ./curl_api_test
//   VOX_SYSTEM_LIBCURL=1 ./curl_api_test
#include "curl_api.h"
#include <assert.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>

static const char *const homebrew_libraries[] = {
    "/opt/homebrew/opt/curl/lib/libcurl.4.dylib",
    "/usr/local/opt/curl/lib/libcurl.4.dylib",
};

// The provider this host should select: the first installed Homebrew curl
// with SecTrust verification, otherwise the system library.
static const char *expected_provider(void) {
    const char *system_only = getenv("VOX_SYSTEM_LIBCURL");
    if (system_only && *system_only) return VOX_SYSTEM_LIBCURL_PATH;
    for (size_t index = 0; index < sizeof(homebrew_libraries) / sizeof(homebrew_libraries[0]); ++index) {
        void *library = dlopen(homebrew_libraries[index], RTLD_NOW | RTLD_LOCAL);
        if (!library) continue;
        int secure = vox_curl_library_has_apple_sectrust(library);
        dlclose(library);
        if (secure) return homebrew_libraries[index];
    }
    return VOX_SYSTEM_LIBCURL_PATH;
}

// Homebrew's opt/ paths are symlinks into its Cellar; compare the files.
// System libraries exist only in the dyld shared cache, under their names.
static void check_provider(void *symbol, const char *expected) {
    Dl_info provider = {0};
    assert(dladdr(symbol, &provider));
    if (strcmp(provider.dli_fname, expected) == 0) return;
    char actual_path[PATH_MAX], expected_path[PATH_MAX];
    assert(realpath(provider.dli_fname, actual_path));
    assert(realpath(expected, expected_path));
    assert(strcmp(actual_path, expected_path) == 0);
}

int main(void) {
    const char *expected = expected_provider();
    assert(!vox_curl_library_loaded());
    assert(vox_curl_global_init(CURL_GLOBAL_ALL) == CURLE_OK);
    assert(vox_curl_library_loaded());
    const VoxCurlApi *api = vox_curl_api();
    assert(strcmp(vox_curl_library_path, expected) == 0);
    check_provider((void *)api->global_init, expected);
    check_provider((void *)api->easy_init, expected);
    check_provider((void *)api->multi_init, expected);
    // Only Homebrew's OpenSSL curl needs SecTrust selected per handle.
    assert(vox_curl_uses_native_ca == (strcmp(expected, VOX_SYSTEM_LIBCURL_PATH) != 0));
    void *easy = vox_curl_easy_init();
    void *multi = vox_curl_multi_init();
    assert(easy && multi);
    assert(vox_curl_server_trust(easy, NULL) == CURLE_OK);
    assert(vox_curl_server_trust(easy, "/nonexistent/vox-ca.pem") == CURLE_OK);
    assert(vox_curl_setopt_long(easy, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_2TLS) == CURLE_OK);
    assert(vox_curl_multi_add_handle(multi, easy) == CURLM_OK);
    assert(vox_curl_multi_remove_handle(multi, easy) == CURLM_OK);
    vox_curl_easy_cleanup(easy);
    assert(vox_curl_multi_cleanup(multi) == CURLM_OK);
    printf("PASS curl provider %s native_ca=%d\n", vox_curl_library_path, vox_curl_uses_native_ca);
    return 0;
}
