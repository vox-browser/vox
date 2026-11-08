#pragma once
#include <errno.h>
#include <process.h>
#include <stdint.h>
#include <string.h>
#include <wchar.h>
#include "../platform/windows_path.h"
#include "../processlock/lock.h"

static int vox_tabs_create_directory(char *pattern) {
    size_t length = strlen(pattern);
    if (length < 6) return EINVAL;
    static LONG sequence;
    for (int attempt = 0; attempt < 128; ++attempt) {
        LARGE_INTEGER clock;
        QueryPerformanceCounter(&clock);
        uint64_t value = (uint64_t)clock.QuadPart ^ ((uint64_t)GetCurrentProcessId() << 32)
            ^ (uint64_t)InterlockedIncrement(&sequence);
        for (size_t i = length - 6; i < length; ++i) {
            pattern[i] = "abcdefghijklmnopqrstuvwxyz0123456789"[value % 36];
            value /= 36;
        }
        wchar_t *wide = vox_windows_wide_path(pattern);
        if (!wide) return EINVAL;
        BOOL created = CreateDirectoryW(wide, NULL);
        DWORD error = GetLastError();
        free(wide);
        if (created) return 0;
        if (error != ERROR_ALREADY_EXISTS) return EACCES;
    }
    return EEXIST;
}

static int vox_tabs_lock(const char *path) { return vox_profile_lock(path); }
static void vox_tabs_unlock(int fd) { vox_profile_unlock(fd); }

// Quote a single CRT argument, including runs of backslashes before quotes
// and the closing delimiter. _wspawnve combines these arguments verbatim.
static wchar_t *vox_tabs_quote_argument(const wchar_t *input) {
    size_t length = wcslen(input);
    wchar_t *result = malloc((length * 2 + 3) * sizeof(wchar_t));
    if (!result) return NULL;
    wchar_t *out = result;
    *out++ = L'"';
    while (*input) {
        size_t slashes = 0;
        while (*input == L'\\') { ++slashes; ++input; }
        size_t copies = slashes * ((*input == L'"' || !*input) ? 2 : 1);
        while (copies--) *out++ = L'\\';
        if (!*input) break;
        if (*input == L'"') *out++ = L'\\';
        *out++ = *input++;
    }
    *out++ = L'"';
    *out = 0;
    return result;
}

static void vox_tabs_free_vector(wchar_t **vector) {
    if (!vector) return;
    for (size_t i = 0; vector[i]; ++i) free(vector[i]);
    free(vector);
}
static wchar_t **vox_tabs_wide_vector(char **input, int quote) {
    size_t count = 0;
    while (input[count]) ++count;
    wchar_t **result = calloc(count + 1, sizeof(wchar_t *));
    if (!result) return NULL;
    for (size_t i = 0; i < count; ++i) {
        wchar_t *wide = vox_windows_wide_path(input[i]);
        if (!wide) { vox_tabs_free_vector(result); return NULL; }
        result[i] = quote ? vox_tabs_quote_argument(wide) : wide;
        if (quote) free(wide);
        if (!result[i]) { vox_tabs_free_vector(result); return NULL; }
    }
    return result;
}
static int vox_tabs_spawn(const char *exe, char **argv, char **env) {
    wchar_t *file = vox_windows_wide_path(exe);
    wchar_t **arguments = vox_tabs_wide_vector(argv, 1);
    wchar_t **environment = vox_tabs_wide_vector(env, 0);
    intptr_t process = file && arguments && environment
        ? _wspawnve(_P_NOWAIT, file, (const wchar_t *const *)arguments,
            (const wchar_t *const *)environment) : -1;
    free(file);
    vox_tabs_free_vector(arguments);
    vox_tabs_free_vector(environment);
    if (process == -1) return -1;
    DWORD pid = GetProcessId((HANDLE)process);
    CloseHandle((HANDLE)process);
    return pid ? (int)pid : -1;
}
static int vox_tabs_alive(int pid) {
    if (pid <= 0) return 0;
    HANDLE process = OpenProcess(SYNCHRONIZE, FALSE, (DWORD)pid);
    if (!process) return GetLastError() == ERROR_ACCESS_DENIED;
    DWORD status = WaitForSingleObject(process, 0);
    CloseHandle(process);
    return status == WAIT_TIMEOUT;
}
static void vox_tabs_terminate(int pid) {
    if (pid <= 0) return;
    HANDLE process = OpenProcess(PROCESS_TERMINATE, FALSE, (DWORD)pid);
    if (!process) return;
    TerminateProcess(process, 1);
    CloseHandle(process);
}
static int vox_tabs_reap(int pid) { return !vox_tabs_alive(pid); }
