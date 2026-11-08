// Execute on Windows: guard-tests.exe C:\path\to\runtime-guard.exe
// The harness itself should run under the 3 GiB guard used for focused tests.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <assert.h>
#include <process.h>
#include <stdio.h>
#include <string.h>
#include <wchar.h>

static void expect_text(const char *path, const char *expected) {
    FILE *file = fopen(path, "rb");
    assert(file);
    char text[128] = {0};
    fread(text, 1, sizeof(text) - 1, file);
    fclose(file);
    assert(strstr(text, expected));
}

int wmain(int argc, wchar_t **argv) {
    if (argc > 1 && wcscmp(argv[1], L"--child-exit") == 0) {
        assert(argc == 6);
        assert(wcscmp(argv[2], L"a b") == 0);
        assert(wcscmp(argv[3], L"a\"b") == 0);
        assert(wcscmp(argv[4], L"C:\\end\\") == 0);
        assert(wcscmp(argv[5], L"\u0416") == 0);
        puts("child stdout");
        fputs("child stderr\n", stderr);
        return 23;
    }
    if (argc > 1 && wcscmp(argv[1], L"--child-wait") == 0) {
        Sleep(20000);
        return 0;
    }
    if (argc > 1 && wcscmp(argv[1], L"--child-memory") == 0) {
        void *allocation = VirtualAlloc(NULL, 128 * 1024 * 1024,
            MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE);
        if (allocation) { VirtualFree(allocation, 0, MEM_RELEASE); return 0; }
        return 42;
    }
    assert(argc == 2);
    wchar_t self[MAX_PATH];
    DWORD length = GetModuleFileNameW(NULL, self, MAX_PATH);
    assert(length > 0 && length < MAX_PATH);
    // _wspawnv joins arguments verbatim; quote its command line explicitly.
    wchar_t quoted_self[MAX_PATH + 3];
    swprintf(quoted_self, MAX_PATH + 3, L"\"%ls\"", self);
    const wchar_t *exit_args[] = {argv[1], L"10000", L"64", L"exit.stdout",
        L"exit.stderr", quoted_self, L"--child-exit", L"\"a b\"", L"\"a\\\"b\"",
        L"\"C:\\end\\\\\"", L"\u0416", NULL};
    assert(_wspawnv(_P_WAIT, argv[1], exit_args) == 23);
    expect_text("exit.stdout", "child stdout");
    expect_text("exit.stderr", "child stderr");
    const wchar_t *timeout_args[] = {argv[1], L"500", L"64", L"timeout.stdout",
        L"timeout.stderr", quoted_self, L"--child-wait", NULL};
    assert(_wspawnv(_P_WAIT, argv[1], timeout_args) == 124);
    const wchar_t *memory_args[] = {argv[1], L"10000", L"64", L"memory.stdout",
        L"memory.stderr", quoted_self, L"--child-memory", NULL};
    assert(_wspawnv(_P_WAIT, argv[1], memory_args) == 42);
    puts("Windows runtime guard: exit, quoting, streams, timeout and memory limit passed");
    return 0;
}
