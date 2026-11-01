#include <arpa/inet.h>
#include <assert.h>
#include <errno.h>
#include <netdb.h>
#include <stdio.h>
#include <sys/socket.h>
#include <unistd.h>

int main(void) {
    // A missing interposition must fail promptly rather than contacting a host.
    alarm(5);
    struct addrinfo *resolved = NULL;
    assert(getaddrinfo("pikabu.ru", NULL, NULL, &resolved) == EAI_NONAME);
    assert(resolved == NULL);
    assert(getaddrinfo("localhost", NULL, NULL, &resolved) == 0);
    freeaddrinfo(resolved);
    for (int family = 0; family < 2; ++family) {
        struct sockaddr_storage storage = {0};
        struct sockaddr *address = (struct sockaddr *)&storage;
        socklen_t size;
        if (family == 0) {
            struct sockaddr_in *v4 = (struct sockaddr_in *)address;
            v4->sin_family = AF_INET;
            v4->sin_addr.s_addr = htonl(INADDR_LOOPBACK);
            size = sizeof(*v4);
        } else {
            struct sockaddr_in6 *v6 = (struct sockaddr_in6 *)address;
            v6->sin6_family = AF_INET6;
            v6->sin6_addr = in6addr_loopback;
            size = sizeof(*v6);
        }
        address->sa_len = size;
        int server = socket(address->sa_family, SOCK_STREAM, 0);
        assert(server >= 0);
        assert(bind(server, address, size) == 0);
        assert(listen(server, 4) == 0);
        assert(getsockname(server, address, &size) == 0);
        sa_endpoints_t endpoints = { .sae_dstaddr = address, .sae_dstaddrlen = size };
        for (int extended = 0; extended < 2; ++extended) {
            int client = socket(address->sa_family, SOCK_STREAM, 0);
            assert(client >= 0);
            int result = extended ? connectx(client, &endpoints, SAE_ASSOCID_ANY, 0,
                NULL, 0, NULL, NULL) : connect(client, address, size);
            assert(result == 0);
            int accepted = accept(server, NULL, NULL);
            assert(accepted >= 0);
            close(accepted);
            close(client);
        }
        // Documentation addresses, denied before either socket API can send.
        assert(inet_pton(address->sa_family, family ? "2001:db8::1" : "192.0.2.1",
            family ? (void *)&((struct sockaddr_in6 *)address)->sin6_addr
                   : (void *)&((struct sockaddr_in *)address)->sin_addr) == 1);
        for (int extended = 0; extended < 2; ++extended) {
            int client = socket(address->sa_family, SOCK_STREAM, 0);
            assert(client >= 0);
            errno = 0;
            int result = extended ? connectx(client, &endpoints, SAE_ASSOCID_ANY, 0,
                NULL, 0, NULL, NULL) : connect(client, address, size);
            assert(result == -1 && errno == ENETUNREACH);
            close(client);
        }
        close(server);
    }
    puts("DNS/external connect denied; loopback permitted");
    return 0;
}
