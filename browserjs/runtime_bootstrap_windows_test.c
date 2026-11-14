/* Run against the same Windows JavaScriptCore.dll shipped with the browser. */
#define WIN32_LEAN_AND_MEAN
#include "runtime_bootstrap_windows.h"
#include <assert.h>
#include <stdbool.h>
#include <stdio.h>
#include <wchar.h>

static bool (__cdecl *is_main_thread)(void);
static void *(__cdecl *main_loop)(void);
static void *expected_loop;

static DWORD WINAPI worker(void *unused)
{
    (void)unused;
    assert(vox_browserjs_initialize_windows_main_thread());
    assert(!is_main_thread());
    assert(main_loop() == expected_loop);
    return 0;
}

int wmain(int argc, wchar_t **argv)
{
    if (argc < 2 || argc > 3) return 2;
    assert(!vox_browserjs_initialize_windows_main_thread());
    HMODULE library = LoadLibraryExW(argv[1], NULL, LOAD_WITH_ALTERED_SEARCH_PATH);
    assert(library);
    main_loop = (void *)GetProcAddress(library, "?mainSingleton@RunLoop@WTF@@SAAEAV12@XZ");
    is_main_thread = (void *)GetProcAddress(library, "?isMainThread@WTF@@YA_NXZ");
    void *(__cdecl *memory_pressure)(void) =
        (void *)GetProcAddress(library, "?singleton@MemoryPressureHandler@WTF@@SAAEAV12@XZ");
    assert(main_loop && is_main_thread && memory_pressure);
    if (argc == 3) {
        if (wcscmp(argv[2], L"--uninitialized-control")) return 2;
        assert(!main_loop());
        puts("CONTROL: missing main run loop; invoking the failing timer constructor");
        fflush(stdout);
        memory_pressure(); /* Must reproduce the original access violation. */
        return 1;
    }
    assert(vox_browserjs_initialize_windows_main_thread());
    expected_loop = main_loop();
    assert(expected_loop && is_main_thread());
    assert(memory_pressure()); /* The original crashing path, without timers disabled. */
    assert(vox_browserjs_initialize_windows_main_thread());
    assert(main_loop() == expected_loop);
    HANDLE thread = CreateThread(NULL, 0, worker, NULL, 0, NULL);
    assert(thread);
    assert(WaitForSingleObject(thread, 120000) == WAIT_OBJECT_0);
    DWORD code = 1;
    assert(GetExitCodeThread(thread, &code) && code == 0);
    CloseHandle(thread);
    puts("PASS: Windows JSC main run loop, memory-pressure timer and worker identity");
    return 0;
}
