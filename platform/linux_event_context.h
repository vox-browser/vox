#pragma once
#include <glib.h>
#include <stdbool.h>
#ifdef _WIN32
#include <windows.h>
#include "native_state.h"
VOX_NATIVE_STATE DWORD vox_glib_main_thread;
__attribute__((constructor)) static void vox_glib_record_main_thread(void) {
    vox_glib_main_thread = GetCurrentThreadId();
}
static bool libweb_v_is_main_thread(void) { return GetCurrentThreadId() == vox_glib_main_thread; }
#else
#include <unistd.h>
#include <sys/syscall.h>

static bool libweb_v_is_main_thread(void) { return syscall(SYS_gettid) == getpid(); }
#endif
static GMainContext *libweb_v_thread_event_context(void) {
    GMainContext *context = g_main_context_get_thread_default();
    if (context) return context;
    if (libweb_v_is_main_thread()) return g_main_context_default();
    // Threads without an embedding context still own a distinct event queue.
    // Never redirect a worker's callbacks onto the browser's main thread.
    static GPrivate worker_context = G_PRIVATE_INIT((GDestroyNotify)g_main_context_unref);
    context = g_private_get(&worker_context);
    if (!context) {
        context = g_main_context_new();
        g_private_set(&worker_context, context);
    }
    return context;
}
