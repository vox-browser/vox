#ifndef VOX_BROWSERJS_RUNTIME_BOOTSTRAP_WINDOWS_H
#define VOX_BROWSERJS_RUNTIME_BOOTSTRAP_WINDOWS_H

#include <windows.h>

/* The pinned Windows JSC C API initializes threading, but not WTF's main
 * run loop. MemoryPressureHandler constructs timers on that loop, including
 * when deferred GC runs. Initialize it on the application's main thread,
 * before any agent can create a context. The export is from the MSVC-built
 * JavaScriptCore.dll; no C++ objects cross this boundary.
 */
static int vox_browserjs_initialize_windows_main_thread(void)
{
    HMODULE library = GetModuleHandleW(L"JavaScriptCore.dll");
    void (__cdecl *initialize)(void) = library
        ? (void *)GetProcAddress(library, "?initializeMainThread@WTF@@YAXXZ")
        : NULL;
    if (!initialize) return 0;
    initialize(); /* WTF internally makes this operation idempotent. */
    return 1;
}

#endif
