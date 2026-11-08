#pragma once
#include <windows.h>
#include <stdlib.h>

// V paths are UTF-8; the Windows filesystem boundary uses UTF-16.
static wchar_t *vox_windows_wide_path(const char *path) {
    if (!path) return NULL;
    int count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, NULL, 0);
    if (!count) return NULL;
    wchar_t *wide = (wchar_t *)malloc((size_t)count * sizeof(wchar_t));
    if (!wide) return NULL;
    if (!MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, wide, count)) {
        free(wide);
        return NULL;
    }
    return wide;
}
