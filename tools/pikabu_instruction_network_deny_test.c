#include <netdb.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <stdio.h>
#include <errno.h>
#include <assert.h>
int main(void) {
 struct addrinfo *info=0;
 assert(getaddrinfo("example.com","443",0,&info)==EAI_NONAME);
 assert(getaddrinfo("127.0.0.1","443",0,&info)==0);freeaddrinfo(info);
 int fd=socket(AF_INET,SOCK_STREAM,0);
 struct sockaddr_in a={.sin_len=sizeof(a),.sin_family=AF_INET,.sin_port=htons(443)};
 inet_pton(AF_INET,"203.0.113.1",&a.sin_addr);
 assert(connect(fd,(struct sockaddr*)&a,sizeof(a))==-1 && errno==ENETUNREACH);close(fd);
 int server=socket(AF_INET,SOCK_STREAM,0);a.sin_port=0;a.sin_addr.s_addr=htonl(INADDR_LOOPBACK);
 assert(bind(server,(struct sockaddr*)&a,sizeof(a))==0);assert(listen(server,1)==0);
 socklen_t n=sizeof(a);assert(getsockname(server,(struct sockaddr*)&a,&n)==0);
 fd=socket(AF_INET,SOCK_STREAM,0);assert(connect(fd,(struct sockaddr*)&a,sizeof(a))==0);
 close(fd);close(server);puts("DNS/external connect denied; loopback permitted");
}
