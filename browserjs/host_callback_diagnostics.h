// Diagnostic registration stacks contain native addresses, never author data.
#ifndef VOX_HOST_CALLBACK_DIAGNOSTICS_H
#define VOX_HOST_CALLBACK_DIAGNOSTICS_H
#ifdef _WIN32
#include <windows.h>
#else
#include <execinfo.h>
#include <dlfcn.h>
#endif
#include <stdint.h>
#include <stdio.h>
static int vox_host_callback_registration_stack(void **frames, int capacity)
{
#ifdef _WIN32
    return (int)CaptureStackBackTrace(0, capacity, frames, NULL);
#else
    return backtrace(frames, capacity);
#endif
}
static uintptr_t vox_host_callback_image_base(void)
{
#ifdef _WIN32
    return (uintptr_t)GetModuleHandleW(NULL);
#else
    Dl_info info = {0};
    return dladdr((const void *)vox_host_callback_image_base, &info)
        ? (uintptr_t)info.dli_fbase : 0;
#endif
}
static void vox_host_callback_report(const char *json)
{
    fprintf(stderr, "VOX_HOST_CALLBACK %s\n", json);
}
#endif
