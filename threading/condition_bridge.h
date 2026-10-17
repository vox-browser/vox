#pragma once
#include <assert.h>
#include <pthread.h>
#include <stdlib.h>

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
static void vox_thread_pool_signal(void* state) { if (pthread_cond_signal(&((VoxThreadPoolCondition*)state)->condition)) abort(); }
static void vox_thread_pool_set_name(char const* name)
{
#ifdef __APPLE__
    pthread_setname_np(name);
#elif defined(__linux__)
    pthread_setname_np(pthread_self(), name);
#endif
}
