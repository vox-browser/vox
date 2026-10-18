#include "../adblock/worker_transport.h"
#include <assert.h>
#include <sys/time.h>
static int descriptors(void) { int n=0; for(int i=0;i<1024;i++) if(fcntl(i,F_GETFD)>=0)n++; return n; }
static void alarm_handler(int signal_number) { (void)signal_number; }
static void assert_reaped(int pid) { int status=0; errno=0; assert(waitpid(pid,&status,WNOHANG)==-1 && errno==ECHILD); }
static int evaluate(const char *source,unsigned char **out,size_t *size) {
    return vox_adblock_worker_evaluate((const unsigned char*)source,strlen(source),out,size);
}
int main(int argc,char **argv) {
    assert(argc==3);
    assert(vox_adblock_worker_configure((const unsigned char*)"relative",8,100)==EINVAL);
    assert(vox_adblock_worker_configure((const unsigned char*)"/tmp/a\0b",8,100)==EINVAL);
    assert(vox_adblock_worker_configure((const unsigned char*)argv[1],strlen(argv[1]),3000)==0);
    int baseline=descriptors();
    unsigned char raw[]={0,0xef,0xbb,0xbf,0x80,0xf0,0x9f,0x8c,0x8d,0};
    unsigned char *out=NULL;size_t size=0;
    int first=vox_adblock_worker_evaluate(raw,sizeof raw,&out,&size);
    if(first!=VOX_AB_RESULT)fprintf(stderr,"first evaluation kind=%d message=%s\n",first,out?(char*)out:"(nil)");
    assert(first==VOX_AB_RESULT);
    assert(size==sizeof raw && !memcmp(out,raw,size));free(out);
    int pid=vox_adblock_worker_get_pid();assert(pid>0);
    uint64_t footprint=0;assert(vox_adblock_worker_memory_bytes(&footprint)==0&&footprint>0);
    assert(vox_adblock_worker_configure(NULL,0,0)==EBUSY);
    size_t large_size=2*1024*1024; unsigned char *large=malloc(large_size);
    for(size_t i=0;i<large_size;i++) large[i]=(unsigned char)i;
    assert(vox_adblock_worker_evaluate(large,large_size,&out,&size)==VOX_AB_RESULT);
    assert(size==large_size && !memcmp(out,large,size));free(out);free(large);
    assert(vox_adblock_worker_release()==1);assert_reaped(pid);
    assert(vox_adblock_worker_release()==0);assert(descriptors()==baseline);
    assert(vox_adblock_worker_memory_bytes(&footprint)==0&&footprint==0);
    const char *modes[]={"startup-eof","startup-hang","wrong-id","truncate","oversize","exit","hang"};
    setenv("VOX_AB_FAKE_LOG",argv[2],1);unlink(argv[2]);
    for(size_t i=0;i<sizeof modes/sizeof *modes;i++) {
        setenv("VOX_AB_FAKE_MODE",modes[i],1);
        assert(evaluate("one-shot-effect",&out,&size)==VOX_AB_TRANSPORT_ERROR);
        assert(size>0);free(out);
        assert(vox_adblock_worker_get_pid()==0);assert(descriptors()==baseline);
    }
    struct stat st;assert(stat(argv[2],&st)==0 && st.st_size==5*8); /* Exactly once per request; startup failures never evaluate. */
    setenv("VOX_AB_FAKE_MODE","init-error",1);
    assert(evaluate("1",&out,&size)==VOX_AB_INIT_ERROR);
    assert(size==20&&!memcmp(out,"fixture init failure",20));free(out);
    assert(vox_adblock_worker_get_pid()==0&&descriptors()==baseline);
    /* SIGPIPE is contained without changing the caller's pending signal state. */
    int ends[2];assert(pipe(ends)==0);close(ends[0]);
    sigset_t set,previous,pending;sigemptyset(&set);sigaddset(&set,SIGPIPE);
    assert(pthread_sigmask(SIG_BLOCK,&set,&previous)==0);
    assert(vox_ab_write_without_sigpipe(ends[1],"x",1)==-1&&errno==EPIPE);
    sigpending(&pending);assert(!sigismember(&pending,SIGPIPE));
    raise(SIGPIPE);sigpending(&pending);assert(sigismember(&pending,SIGPIPE));
    assert(vox_ab_write_without_sigpipe(ends[1],"x",1)==-1&&errno==EPIPE);
    sigpending(&pending);assert(sigismember(&pending,SIGPIPE));
    int signal_number;assert(sigwait(&set,&signal_number)==0&&signal_number==SIGPIPE);
    assert(pthread_sigmask(SIG_SETMASK,&previous,NULL)==0);close(ends[1]);
    /* Repeated EINTR must preserve the original deadline. */
    struct sigaction action={0},old;action.sa_handler=alarm_handler;sigaction(SIGALRM,&action,&old);
    struct itimerval timer={{0,5000},{0,5000}},stop={0};setitimer(ITIMER_REAL,&timer,NULL);
    setenv("VOX_AB_FAKE_MODE","hang-on-command",1);
    assert(evaluate("warm",&out,&size)==VOX_AB_RESULT);free(out);
    vox_adblock_worker_timeout=200;
    int64_t start=vox_ab_now_ms();assert(evaluate("hang",&out,&size)==VOX_AB_TRANSPORT_ERROR);free(out);
    assert(vox_ab_now_ms()-start<1200);
    setitimer(ITIMER_REAL,&stop,NULL);sigaction(SIGALRM,&old,NULL);
    assert(descriptors()==baseline);
    unsetenv("VOX_AB_FAKE_MODE");unsetenv("VOX_AB_FAKE_LOG");
    assert(evaluate("restored",&out,&size)==VOX_AB_RESULT);assert(size==8&&!memcmp(out,"restored",8));free(out);
    pid=vox_adblock_worker_get_pid();kill(pid,SIGKILL);
    assert(evaluate("not-retried",&out,&size)==VOX_AB_TRANSPORT_ERROR);free(out);assert_reaped(pid);
    assert(evaluate("new-independent-request",&out,&size)==VOX_AB_RESULT);free(out);
    assert(vox_adblock_worker_release());assert(descriptors()==baseline);
    /* An unrelated open descriptor must not leak through posix_spawn. */
    int sentinel=open("/dev/null",O_RDONLY);assert(sentinel>=0);
    assert(dup2(sentinel,50)==50);close(sentinel);
    setenv("VOX_AB_FAKE_MODE","fd-audit",1);
    assert(evaluate("audit",&out,&size)==VOX_AB_RESULT);assert(size==6&&!memcmp(out,"closed",6));free(out);
    assert(vox_adblock_worker_release());close(50);
    /* Eval may be unbounded or very long; graceful shutdown has its own fixed shared budget. */
    assert(vox_adblock_worker_configure((const unsigned char*)argv[1],strlen(argv[1]),15000)==0);
    setenv("VOX_AB_FAKE_MODE","hang-on-quit",1);
    assert(evaluate("ready",&out,&size)==VOX_AB_RESULT);free(out);
    int64_t release_start=vox_ab_now_ms();assert(vox_adblock_worker_release());
    int64_t release_ms=vox_ab_now_ms()-release_start;
    assert(release_ms>=1800&&release_ms<4000);
    printf("shared shutdown deadline observed %lld ms\n",(long long)release_ms);
    unsetenv("VOX_AB_FAKE_MODE");
    assert(vox_adblock_worker_memory_bytes(&footprint)==0&&footprint==0);
    assert(descriptors()==baseline);
    assert(vox_adblock_worker_configure(NULL,0,0)==0);
    puts("native transport tests passed: exact bytes, 2MiB partial I/O, deadlines/EINTR, protocol faults, no retry, SIGPIPE, crash/reap/fd cleanup");
    return 0;
}
