#ifndef VOX_ADBLOCK_ENABLED_SNAPSHOT_TEST_H
#define VOX_ADBLOCK_ENABLED_SNAPSHOT_TEST_H

#include "../browserjs/jsc_abi.h"
#include "runtime.h"

// A recursive read regression must fail ownership checks, not hang the suite.
// This fixture has no filtering workers and restores the ordinary mutex type.
static int vox_adblock_test_mutex_errorcheck(int enabled) {
    pthread_mutexattr_t attributes;
    int result = pthread_mutexattr_init(&attributes);
    if (result) return result;
    result = pthread_mutexattr_settype(&attributes,
        enabled ? PTHREAD_MUTEX_ERRORCHECK : PTHREAD_MUTEX_NORMAL);
    if (!result) result = pthread_mutex_destroy(&vox_adblock_mutex);
    if (!result) result = pthread_mutex_init(&vox_adblock_mutex, &attributes);
    pthread_mutexattr_destroy(&attributes);
    return result;
}

#endif
