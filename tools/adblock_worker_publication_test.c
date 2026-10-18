#include <spawn.h>
#include <pthread.h>
#include <stdatomic.h>
#include <assert.h>
#include <stdio.h>
#include <time.h>
static int paused_spawn(pid_t *, const char *, const posix_spawn_file_actions_t *, const posix_spawnattr_t *, char *const[], char *const[]);
#define posix_spawn paused_spawn
#include "../adblock/worker_transport.h"
#undef posix_spawn
static pthread_mutex_t gate=PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t changed=PTHREAD_COND_INITIALIZER;
static int created, proceed;
static atomic_int sampled;
static uint64_t sampled_bytes;
static int sample_result;
static int paused_spawn(pid_t *pid,const char *path,const posix_spawn_file_actions_t *actions,const posix_spawnattr_t *attributes,char *const args[],char *const env[]) {
    int result=posix_spawn(pid,path,actions,attributes,args,env);
    if(!result) {
        pthread_mutex_lock(&gate);created=1;pthread_cond_broadcast(&changed);
        while(!proceed)pthread_cond_wait(&changed,&gate);
        pthread_mutex_unlock(&gate);
    }
    return result;
}
static void *evaluate(void *unused) {
    (void)unused;unsigned char *out=NULL;size_t size=0;
    assert(vox_adblock_worker_evaluate((const unsigned char*)"42",2,&out,&size)==VOX_AB_RESULT);
    assert(size==2&&!memcmp(out,"42",2));free(out);return NULL;
}
static void *sample(void *unused) {
    (void)unused;sample_result=vox_adblock_worker_memory_bytes(&sampled_bytes);atomic_store(&sampled,1);return NULL;
}
int main(int argc,char **argv) {
    assert(argc==2);assert(vox_adblock_worker_configure((const unsigned char*)argv[1],strlen(argv[1]),3000)==0);
    pthread_t evaluation,sampler;assert(pthread_create(&evaluation,NULL,evaluate,NULL)==0);
    pthread_mutex_lock(&gate);while(!created)pthread_cond_wait(&changed,&gate);pthread_mutex_unlock(&gate);
    assert(pthread_create(&sampler,NULL,sample,NULL)==0);
    struct timespec pause={0,50000000};nanosleep(&pause,NULL);
    /* A real child already exists inside posix_spawn. Sampling must wait for
       publication, never return successful zero while it is alive. */
    assert(atomic_load(&sampled)==0);
    pthread_mutex_lock(&gate);proceed=1;pthread_cond_broadcast(&changed);pthread_mutex_unlock(&gate);
    pthread_join(evaluation,NULL);pthread_join(sampler,NULL);
    assert(sample_result==0&&sampled_bytes>0);
    assert(vox_adblock_worker_release());assert(vox_adblock_worker_memory_bytes(&sampled_bytes)==0&&sampled_bytes==0);
    puts("PASS real starting-child publication blocks sampling until accounted; stopped child zero");return 0;
}
