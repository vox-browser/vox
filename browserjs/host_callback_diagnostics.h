// Diagnostic registration stacks contain native addresses, never author data.
#ifndef VOX_HOST_CALLBACK_DIAGNOSTICS_H
#define VOX_HOST_CALLBACK_DIAGNOSTICS_H
#include <execinfo.h>
#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>
static int vox_host_callback_registration_stack(void **frames, int capacity)
{
    return backtrace(frames, capacity);
}
static uintptr_t vox_host_callback_image_base(void)
{
    Dl_info info = {0};
    return dladdr((const void *)vox_host_callback_image_base, &info)
        ? (uintptr_t)info.dli_fbase : 0;
}
static void vox_host_callback_report(const char *json)
{
    fprintf(stderr, "VOX_HOST_CALLBACK %s\n", json);
}
#endif
