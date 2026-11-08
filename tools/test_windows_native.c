// Compile with MinGW; run on Windows to check the native service boundaries.
#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <windows.h>
#include <assert.h>
#include <stdint.h>
#include "../libgc/primitive_storage_host.h"
#include "../browsernet/websocket_wake.h"
#include "../browsertabs/process_windows.h"
#include "../libregex/rust_panic_windows.h"

static void test_virtual_memory(void) {
    size_t page = vox_gc_storage_page_size();
    assert(page > 0);
    unsigned char *region = vox_gc_reserve_address_space(page * 4);
    assert(region != (void *)-1);
    assert(vox_gc_commit_memory(region, page * 2) == region);
    region[0] = 42;
    region[page * 2 - 1] = 17;
    assert(vox_gc_decommit_memory(region, page * 2) == region);
    assert(vox_gc_commit_memory(region, page * 2) == region);
    assert(region[0] == 0 && region[page * 2 - 1] == 0);
    assert(vox_gc_release_address_space(region, page * 4) == 0);
}

static void test_socket_wakeup(void) {
    WSADATA data;
    assert(WSAStartup(MAKEWORD(2, 2), &data) == 0);
    SOCKET listener = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    assert(listener != INVALID_SOCKET);
    struct sockaddr_in address = {0};
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    assert(bind(listener, (struct sockaddr *)&address, sizeof(address)) == 0);
    assert(listen(listener, 1) == 0);
    int length = sizeof(address);
    assert(getsockname(listener, (struct sockaddr *)&address, &length) == 0);
    SOCKET sender = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    assert(sender != INVALID_SOCKET);
    assert(connect(sender, (struct sockaddr *)&address, sizeof(address)) == 0);
    SOCKET receiver = accept(listener, NULL, NULL);
    assert(receiver != INVALID_SOCKET);
    void *wake = vox_websocket_wake_create();
    assert(wake);
    assert(vox_websocket_wake_wait(wake, (int64_t)receiver, 0) == 0);
    vox_websocket_wake_signal(wake);
    assert(vox_websocket_wake_wait(wake, (int64_t)receiver, 1000) == 2);
    assert(vox_websocket_wake_wait(wake, (int64_t)receiver, 0) == 0);
    assert(send(sender, "x", 1, 0) == 1);
    assert(vox_websocket_wake_wait(wake, (int64_t)receiver, 1000) == 1);
    char byte;
    assert(recv(receiver, &byte, 1, 0) == 1 && byte == 'x');
    closesocket(receiver);
    closesocket(sender);
    closesocket(listener);
    vox_websocket_wake_close(wake);
    WSACleanup();
}

static void test_argument_quoting(void) {
    wchar_t *quoted = vox_tabs_quote_argument(L"C:\\a b\\");
    assert(quoted && wcscmp(quoted, L"\"C:\\a b\\\\\"") == 0);
    free(quoted);
    quoted = vox_tabs_quote_argument(L"a\"b");
    assert(quoted && wcscmp(quoted, L"\"a\\\"b\"") == 0);
    free(quoted);
}

static bool panic_active(void) { return true; }
static void test_panic_handoff(void) {
    char message[] = {'a', 0, 'b'};
    ladybird_rust_panic(message, sizeof(message), "source.rs", 9, 4, 7, panic_active);
    message[0] = 'x';
    assert(strcmp(vox_regex_rust_panic_text, "a?b at source.rs:4:7") == 0);
    assert(vox_regex_rust_is_panicking == panic_active);
    char large[9000];
    memset(large, 'a', sizeof(large));
    ladybird_rust_panic(large, sizeof(large), large, sizeof(large), 1, 1, panic_active);
    assert(strlen(vox_regex_rust_panic_text) < sizeof(vox_regex_rust_panic_text));
    assert(strstr(vox_regex_rust_panic_text, "[truncated]") != NULL);
    assert(strstr(vox_regex_rust_panic_text, "[location unavailable]") != NULL);
}

int main(void) {
    test_virtual_memory();
    test_socket_wakeup();
    test_argument_quoting();
    test_panic_handoff();
    return 0;
}
