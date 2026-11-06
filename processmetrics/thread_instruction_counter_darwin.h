#ifndef VOX_THREAD_INSTRUCTION_COUNTER_DARWIN_H
#define VOX_THREAD_INSTRUCTION_COUNTER_DARWIN_H
#include <errno.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>

/* XNU bsd/sys/resource_private.h: THSC_CPI=1, two uint64_t fields.
 * https://github.com/apple-oss-distributions/xnu/blob/main/bsd/sys/resource_private.h
 * Weak import keeps absent/private SPI and unsupported hardware fail-closed. */
extern int thread_selfcounts(uint32_t, void *, size_t) __attribute__((weak_import));
struct vox_thread_cpi { uint64_t instructions, cycles; };
_Static_assert(sizeof(struct vox_thread_cpi) == 16, "Unexpected thread CPI size");
_Static_assert(offsetof(struct vox_thread_cpi, cycles) == 8, "Unexpected thread CPI offset");
typedef int (*vox_thread_counts_reader)(uint32_t, void *, size_t);

static int vox_thread_instructions_from_reader(uint64_t *instructions,
    vox_thread_counts_reader reader)
{
    if (!instructions) return EINVAL;
    *instructions = 0;
    if (!reader) return ENOTSUP;
    struct vox_thread_cpi counts = {0};
    errno = 0;
    int status = reader(1, &counts, sizeof(counts));
    if (status != 0) return errno ? errno : status > 0 ? status : EIO;
    if (!counts.instructions || !counts.cycles) return ENOTSUP;
    *instructions = counts.instructions;
    return 0;
}

static int vox_thread_instructions(uint64_t *instructions)
{
    return vox_thread_instructions_from_reader(instructions, thread_selfcounts);
}

/* These supplement the process/coalition endpoints; they never replace them.
 * A native capture checkpoint must belong to the main thread to join its
 * stage stream. No logging occurs in ordinary browser runs. */
static void vox_thread_instruction_checkpoint(const char *label)
{
    const char *enabled = getenv("VOX_DIAGNOSTIC_THREAD_LOAD_STAGES");
    const char *profile = getenv("VOX_PROFILE_INSTRUCTIONS");
    if (!enabled || !*enabled || !profile || !*profile) return;
    uint64_t count = 0;
    int status = pthread_main_np() ? vox_thread_instructions(&count) : EINVAL;
    if (status)
        fprintf(stderr, "Vox thread instructions unavailable: %s error=%d\n", label, status);
    else
        fprintf(stderr, "Vox thread instructions cumulative: %s %llu\n", label,
            (unsigned long long)count);
}
#endif
