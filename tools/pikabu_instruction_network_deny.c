// Process-local offline guard for the frozen Pikabu instruction benchmark.
// No system DNS, hosts, proxy, or trust settings are changed.
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <errno.h>
#include <string.h>

static int pikabu_getaddrinfo(const char *name, const char *service,
                             const struct addrinfo *hints, struct addrinfo **result) {
    if (name && strcmp(name, "localhost") && strcmp(name, "127.0.0.1") && strcmp(name, "::1")) {
        *result = 0;
        return EAI_NONAME;
    }
    return getaddrinfo(name, service, hints, result);
}

static int pikabu_connect(int fd, const struct sockaddr *address, socklen_t length) {
    if (address && address->sa_family == AF_INET) {
        const struct sockaddr_in *v4 = (const struct sockaddr_in *)address;
        if ((ntohl(v4->sin_addr.s_addr) >> 24) != 127) {
            errno = ENETUNREACH;
            return -1;
        }
    } else if (address && address->sa_family == AF_INET6) {
        const struct sockaddr_in6 *v6 = (const struct sockaddr_in6 *)address;
        if (!IN6_IS_ADDR_LOOPBACK(&v6->sin6_addr)) {
            errno = ENETUNREACH;
            return -1;
        }
    }
    return connect(fd, address, length);
}

#define INTERPOSE(replacement, original) \
    __attribute__((used)) static struct { const void *replacement; const void *original; } \
    interpose_##original __attribute__((section("__DATA,__interpose"))) = { \
        (const void *)(unsigned long)&replacement, (const void *)(unsigned long)&original }
INTERPOSE(pikabu_getaddrinfo, getaddrinfo);
INTERPOSE(pikabu_connect, connect);
