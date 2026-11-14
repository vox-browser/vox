/* Native request transport: Windows roots, explicit roots and failed trust. */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "../browsernet/cancellable_transport.h"

typedef struct { size_t bytes, saved; char body[1024]; } Response;
static size_t header(void *data, size_t size, size_t count, void *owner) {
    (void)data; (void)owner;
    return size * count;
}
static size_t body(void *data, size_t size, size_t count, void *owner) {
    Response *response = owner;
    if (size && count > SIZE_MAX / size) return 0;
    size_t length = size * count;
    size_t copy = sizeof(response->body) - 1 - response->saved;
    if (copy > length) copy = length;
    memcpy(response->body + response->saved, data, copy);
    response->saved += copy;
    response->body[response->saved] = 0;
    response->bytes += length;
    return length;
}
static int check(const char *name, const char *url, const char *bundle,
                 int expected, int fixture) {
    void *scope = vox_resource_scope_create();
    Response response = {0};
    char error[CURL_ERROR_SIZE] = {0};
    int protocol = 0;
    int result = vox_resource_curl_fetch(url, "", bundle, "Vox HTTPS test", NULL,
        &response, scope, header, body, error, false, &protocol);
    vox_resource_scope_release(scope);
    printf("%s: result=%d expected=%d bytes=%llu protocol=%d\n", name, result,
           expected, (unsigned long long)response.bytes, protocol);
    fflush(stdout);
    if (result != expected || (expected == CURLE_OK && !response.bytes) ||
        (fixture && !strstr(response.body, "vox-native-trust-fixture"))) {
        fprintf(stderr, "FAIL: %s: %s\n", name, error);
        return 1;
    }
    return 0;
}
int wmain(int argc, wchar_t **argv) {
    if (argc != 5) {
        fputs("usage: test_windows_https.exe LIVE_HTTPS VALID_FIXTURE_HTTPS "
              "WRONG_HOST_HTTPS CA_BUNDLE\n", stderr);
        return 2;
    }
    char args[4][32768];
    for (int i = 0; i < 4; ++i)
        if (!WideCharToMultiByte(CP_UTF8, 0, argv[i+1], -1, args[i], sizeof(args[i]), NULL, NULL)) return 2;
    char missing[32780];
    snprintf(missing, sizeof(missing), "%s.missing", args[3]);
    printf("libcurl: %s\n", curl_version());
    int failed = 0;
    if (strcmp(args[0], "-"))
        failed |= check("native Windows roots", args[0], "", CURLE_OK, 0);
    failed |= check("untrusted fixture", args[1], "", CURLE_PEER_FAILED_VERIFICATION, 0);
    failed |= check("explicit CA", args[1], args[3], CURLE_OK, 1);
    failed |= check("wrong hostname", args[2], args[3], CURLE_PEER_FAILED_VERIFICATION, 0);
    failed |= check("invalid explicit CA", args[1], missing, CURLE_SSL_CACERT_BADFILE, 0);
    return failed;
}
