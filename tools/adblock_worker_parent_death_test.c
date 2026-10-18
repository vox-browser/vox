#include "../adblock/worker_transport.h"
int main(int argc,char **argv) {
    if(argc!=2||vox_adblock_worker_configure((unsigned char*)argv[1],strlen(argv[1]),0))return 64;
    unsigned char *out=NULL;size_t size=0;
    if(vox_adblock_worker_evaluate((unsigned char*)"42",2,&out,&size)!=VOX_AB_RESULT||size!=2||memcmp(out,"42",2))return 65;
    free(out);printf("%d\n",vox_adblock_worker_get_pid());fflush(stdout);
    int result=vox_adblock_worker_evaluate((unsigned char*)"for(;;){}",9,&out,&size);
    free(out);return result==VOX_AB_RESULT?66:67;
}
