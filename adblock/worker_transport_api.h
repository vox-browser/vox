#ifndef VOX_AB_WORKER_API_H
#define VOX_AB_WORKER_API_H
#include <stddef.h>
#include <stdint.h>
int vox_adblock_self_executable_path(unsigned char **, size_t *);
int vox_adblock_worker_configure(const unsigned char*, size_t, int);
int vox_adblock_worker_is_configured(void);
int vox_adblock_worker_get_pid(void);
int vox_adblock_worker_memory_bytes(uint64_t *);
int vox_adblock_worker_evaluate(const unsigned char*, size_t, unsigned char**, size_t*);
int vox_adblock_worker_release(void);
/* Transfer one idle helper to background shutdown; do not wait for its exit.
   Returns zero without detaching if the retirement slot or thread is unavailable. */
int vox_adblock_worker_release_idle(void);
int vox_adblock_worker_begin_lifetime_watch(void);
int vox_adblock_worker_send_frame(int,int,uint64_t,const unsigned char*,size_t,int);
int vox_adblock_worker_read_frame(int,int*,uint64_t*,unsigned char**,size_t*,int);
#endif
