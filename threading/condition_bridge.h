#pragma once
#include <assert.h>
#include <errno.h>
#include <pthread.h>
#include <stdlib.h>
#include <time.h>

// LibSync::Mutex and ConditionVariablePOSIX.cpp storage projection.
typedef struct {
    pthread_mutex_t mutex;
    pthread_cond_t condition;
} VoxThreadPoolCondition;
static void* vox_thread_pool_condition_create(void)
{
    VoxThreadPoolCondition* state = malloc(sizeof(*state));
    if (!state) return NULL;
    if (pthread_mutex_init(&state->mutex, NULL) != 0) abort();
    if (pthread_cond_init(&state->condition, NULL) != 0) abort();
    return state;
}
static void vox_thread_pool_lock(void* state) { if (pthread_mutex_lock(&((VoxThreadPoolCondition*)state)->mutex)) abort(); }
static void vox_thread_pool_unlock(void* state) { if (pthread_mutex_unlock(&((VoxThreadPoolCondition*)state)->mutex)) abort(); }
static void vox_thread_pool_wait(void* state)
{
    VoxThreadPoolCondition* condition = state;
    if (pthread_cond_wait(&condition->condition, &condition->mutex)) abort();
}
static int vox_thread_pool_wait_for_idle_collection(void* state)
{
    VoxThreadPoolCondition* condition = state;
    struct timespec timeout;
    if (clock_gettime(CLOCK_REALTIME, &timeout)) abort();
    timeout.tv_sec += 1;
    int result = pthread_cond_timedwait(&condition->condition, &condition->mutex, &timeout);
    if (result == ETIMEDOUT) return 0;
    if (result != 0) abort();
    return 1;
}
static void vox_thread_pool_signal(void* state) { if (pthread_cond_signal(&((VoxThreadPoolCondition*)state)->condition)) abort(); }
static void vox_thread_pool_set_name(char const* name)
{
#ifdef __APPLE__
    pthread_setname_np(name);
#elif defined(__linux__)
    pthread_setname_np(pthread_self(), name);
#endif
}
