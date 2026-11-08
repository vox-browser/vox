// Run a Windows test in a private job with a committed-memory limit and timeout.
// Cross-build: x86_64-w64-mingw32-gcc -municode -O2 -o guard.exe this-file.c
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <wchar.h>
#include "../browsertabs/process_windows.h"

static HANDLE output_file(const wchar_t *path, DWORD access) {
    SECURITY_ATTRIBUTES attributes = {sizeof(attributes), NULL, TRUE};
    return CreateFileW(path, access, FILE_SHARE_READ | FILE_SHARE_WRITE,
        &attributes, access == GENERIC_READ ? OPEN_EXISTING : CREATE_ALWAYS,
        FILE_ATTRIBUTE_NORMAL, NULL);
}

int wmain(int argc, wchar_t **argv) {
    if (argc < 6) {
        fputs("usage: guard.exe TIMEOUT_MS LIMIT_MIB STDOUT STDERR EXE [ARG ...]\n", stderr);
        return 125;
    }
    unsigned long timeout = wcstoul(argv[1], NULL, 10);
    unsigned long long limit_mib = wcstoull(argv[2], NULL, 10);
    if (!timeout || !limit_mib || limit_mib > SIZE_MAX / (1024 * 1024)) return 125;
    HANDLE job = CreateJobObjectW(NULL, NULL);
    if (!job) return 125;
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits = {0};
    limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_JOB_MEMORY
        | JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    limits.JobMemoryLimit = (SIZE_T)limit_mib * 1024 * 1024;
    if (!SetInformationJobObject(job, JobObjectExtendedLimitInformation, &limits, sizeof(limits))) {
        fprintf(stderr, "SetInformationJobObject failed: %lu\n", GetLastError());
        CloseHandle(job);
        return 125;
    }
    size_t capacity = 1;
    for (int i = 5; i < argc; ++i) capacity += wcslen(argv[i]) * 2 + 4;
    wchar_t *command = calloc(capacity, sizeof(wchar_t));
    if (!command) { CloseHandle(job); return 125; }
    for (int i = 5; i < argc; ++i) {
        wchar_t *argument = vox_tabs_quote_argument(argv[i]);
        if (!argument) { free(command); CloseHandle(job); return 125; }
        if (i != 5) wcscat(command, L" ");
        wcscat(command, argument);
        free(argument);
    }
    HANDLE out = output_file(argv[3], GENERIC_WRITE);
    HANDLE err = output_file(argv[4], GENERIC_WRITE);
    HANDLE input = output_file(L"NUL", GENERIC_READ);
    if (out == INVALID_HANDLE_VALUE || err == INVALID_HANDLE_VALUE || input == INVALID_HANDLE_VALUE) {
        fprintf(stderr, "Opening standard streams failed: %lu\n", GetLastError());
        if (out != INVALID_HANDLE_VALUE) CloseHandle(out);
        if (err != INVALID_HANDLE_VALUE) CloseHandle(err);
        if (input != INVALID_HANDLE_VALUE) CloseHandle(input);
        free(command); CloseHandle(job); return 125;
    }
    STARTUPINFOW startup = {0};
    startup.cb = sizeof(startup);
    startup.dwFlags = STARTF_USESTDHANDLES;
    startup.hStdOutput = out;
    startup.hStdError = err;
    startup.hStdInput = input;
    PROCESS_INFORMATION child = {0};
    BOOL created = CreateProcessW(argv[5], command, NULL, NULL, TRUE,
        CREATE_SUSPENDED | CREATE_UNICODE_ENVIRONMENT | CREATE_NO_WINDOW,
        NULL, NULL, &startup, &child);
    DWORD creation_error = GetLastError();
    free(command);
    CloseHandle(input); CloseHandle(out); CloseHandle(err);
    if (!created) {
        fprintf(stderr, "CreateProcessW failed: %lu\n", creation_error);
        CloseHandle(job); return 125;
    }
    if (!AssignProcessToJobObject(job, child.hProcess)) {
        fprintf(stderr, "AssignProcessToJobObject failed: %lu\n", GetLastError());
        TerminateProcess(child.hProcess, 125);
        CloseHandle(child.hThread); CloseHandle(child.hProcess); CloseHandle(job);
        return 125;
    }
    if (ResumeThread(child.hThread) == (DWORD)-1) {
        fprintf(stderr, "ResumeThread failed: %lu\n", GetLastError());
        TerminateJobObject(job, 125);
        CloseHandle(child.hThread); CloseHandle(child.hProcess); CloseHandle(job);
        return 125;
    }
    CloseHandle(child.hThread);
    DWORD wait = WaitForSingleObject(child.hProcess, timeout);
    if (wait != WAIT_OBJECT_0) {
        TerminateJobObject(job, wait == WAIT_TIMEOUT ? 124 : 125);
        WaitForSingleObject(child.hProcess, 10000);
    }
    DWORD code = 125;
    GetExitCodeProcess(child.hProcess, &code);
    QueryInformationJobObject(job, JobObjectExtendedLimitInformation, &limits, sizeof(limits), NULL);
    printf("{\"pid\":%lu,\"child_exit_code\":%lu,\"timed_out\":%s,"
        "\"job_memory_limit_bytes\":%llu,\"peak_job_committed_bytes\":%llu}\n",
        child.dwProcessId, code, wait == WAIT_TIMEOUT ? "true" : "false",
        (unsigned long long)limits.JobMemoryLimit, (unsigned long long)limits.PeakJobMemoryUsed);
    CloseHandle(child.hProcess);
    CloseHandle(job);
    return wait == WAIT_OBJECT_0 ? (int)code : (wait == WAIT_TIMEOUT ? 124 : 125);
}
