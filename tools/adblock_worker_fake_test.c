#include "../adblock/worker_transport.h"
int main(int argc, char **argv) {
    if (argc != 2 || strcmp(argv[1], vox_adblock_worker_role) || vox_adblock_worker_begin_lifetime_watch()) return 64;
    const char *mode = getenv("VOX_AB_FAKE_MODE");
    if (!mode) mode = "echo";
    if (!strcmp(mode,"startup-eof")) return 0;
    if (!strcmp(mode,"startup-hang")) { for (;;) pause(); }
    if (!strcmp(mode,"init-error")) return vox_adblock_worker_send_frame(4,VOX_AB_INIT_ERROR,0,(const unsigned char*)"fixture init failure",20,0);
    if (vox_adblock_worker_send_frame(4,VOX_AB_READY,0,NULL,0,0)) return 71;
    for (;;) {
        int kind=0; uint64_t id=0; unsigned char *bytes=NULL; size_t size=0;
        if (vox_adblock_worker_read_frame(3,&kind,&id,&bytes,&size,0)!=1) return 0;
        if(kind==VOX_AB_QUIT) { free(bytes); if(!strcmp(mode,"hang-on-quit")) { for(;;)pause(); } return vox_adblock_worker_send_frame(4,VOX_AB_CLOSED,id,NULL,0,0); }
        const char *path=getenv("VOX_AB_FAKE_LOG");
        if(path) { int fd=open(path,O_WRONLY|O_CREAT|O_APPEND,0600); if(fd>=0) { write(fd,"request\n",8);close(fd); } }
        if (!strcmp(mode,"hang") || (!strcmp(mode,"hang-on-command") && size==4 && !memcmp(bytes,"hang",4))) { free(bytes); for (;;) pause(); }
        if (!strcmp(mode,"exit")) { free(bytes); return 0; }
        if (!strcmp(mode,"wrong-id")) id++;
        if (!strcmp(mode,"truncate")) { write(4,"VAB",3); free(bytes); return 0; }
        if (!strcmp(mode,"oversize")) {
            unsigned char header[24]={'V','A','B','W',0,1,0,VOX_AB_RESULT};
            vox_ab_put32(header+16,UINT32_MAX); write(4,header,24); free(bytes); return 0;
        }
        if (!strcmp(mode,"fd-audit")) {
            free(bytes);const char *answer=fcntl(50,F_GETFD)<0&&errno==EBADF?"closed":"LEAKED";
            bytes=(unsigned char*)strdup(answer);size=strlen(answer);
        }
        int result=vox_adblock_worker_send_frame(4,VOX_AB_RESULT,id,bytes,size,0);
        free(bytes); if(result) return 74;
    }
}
