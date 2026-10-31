#ifndef VOX_CURL_NATIVE_ABI_TEST_H
#define VOX_CURL_NATIVE_ABI_TEST_H
#include <sys/socket.h>
#include <unistd.h>
#include <stdint.h>
static int vox_curl_abi_socket_pair(int32_t* descriptors) { return socketpair(AF_UNIX, SOCK_STREAM, 0, descriptors); }
static void vox_curl_abi_close(int32_t descriptor) { close(descriptor); }
#if defined(__APPLE__) && defined(__aarch64__)
// Darwin's int arguments occupy the low 32 bits. A native caller need not
// initialize the upper register bits; keep them nonzero at this boundary.
__attribute__((naked)) static int vox_curl_abi_call_socket(void* callback, void* owner, int32_t socket, int32_t flags) {
    __asm__ volatile(
        "mov x16, x0\n"
        "mov x5, x1\n"
        "mov w1, w2\n"
        "mov w2, w3\n"
        "mov x3, x5\n"
        "mov x0, xzr\n"
        "mov x4, xzr\n"
        "mov x17, #0x1234\n"
        "lsl x17, x17, #32\n"
        "orr x1, x1, x17\n"
        "orr x2, x2, x17\n"
        "br x16\n");
}
#else
static int vox_curl_abi_call_socket(void* callback, void* owner, int32_t socket, int32_t flags) {
    return ((int (*)(void*, int, int, void*, void*))callback)(NULL, socket, flags, owner, NULL);
}
#endif
#endif
