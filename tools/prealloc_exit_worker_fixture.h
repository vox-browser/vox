#pragma once
#include <pthread.h>
#include <signal.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>

// Register before V's arena cleanup. This callback runs after that cleanup,
// when detached native workers can still be executing during exit().
static pthread_mutex_t exit_worker_mutex = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t exit_worker_condition = PTHREAD_COND_INITIALIZER;
static pthread_t exit_worker_thread;
static const volatile uint8_t *exit_worker_bytes;
static size_t exit_worker_size;
static int exit_worker_ready, exit_worker_started;

static void exit_worker_fault(int signal_number) { _exit(128 + signal_number); }

static void *exit_worker_read(void *unused) {
    (void)unused;
    pthread_mutex_lock(&exit_worker_mutex);
    while (!exit_worker_ready)
        pthread_cond_wait(&exit_worker_condition, &exit_worker_mutex);
    pthread_mutex_unlock(&exit_worker_mutex);
    for (size_t i = 0; i < exit_worker_size; ++i)
        if (exit_worker_bytes[i] != i % 251) _exit(9);
    return NULL;
}

static void exit_worker_after_cleanup(void) {
    if (!exit_worker_started) return;
    pthread_mutex_lock(&exit_worker_mutex);
    exit_worker_ready = 1;
    pthread_cond_signal(&exit_worker_condition);
    pthread_mutex_unlock(&exit_worker_mutex);
    if (pthread_join(exit_worker_thread, NULL)) _exit(8);
    write(STDERR_FILENO, "EXIT_WORKER_OK\n", 15);
}

__attribute__((constructor)) static void exit_worker_register(void) {
    if (atexit(exit_worker_after_cleanup)) _exit(7);
}

static void exit_worker_start(const uint8_t *bytes, size_t size) {
    signal(SIGSEGV, exit_worker_fault);
    signal(SIGBUS, exit_worker_fault);
    exit_worker_bytes = bytes;
    exit_worker_size = size;
    if (pthread_create(&exit_worker_thread, NULL, exit_worker_read, NULL)) _exit(6);
    exit_worker_started = 1;
}
