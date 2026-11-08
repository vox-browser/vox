// SPDX-License-Identifier: BSD-2-Clause
// AK/Assertions.cpp's bounded, thread-local Rust panic handoff. The Rust
// hook still owns unwinding and abort policy; this boundary retains diagnostics.
#pragma once
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

static _Thread_local char vox_regex_rust_panic_text[8193];
static _Thread_local bool (*vox_regex_rust_is_panicking)(void);

static void vox_regex_append_panic_text(size_t *length, const char *text, size_t count) {
    for (size_t i = 0; i < count && *length < sizeof(vox_regex_rust_panic_text) - 1; ++i)
        vox_regex_rust_panic_text[(*length)++] = text[i] ? text[i] : '?';
}

void ladybird_rust_panic(const char *message, size_t message_length,
    const char *filename, size_t filename_length, uint32_t line, uint32_t column,
    bool (*is_panicking)(void)) {
    vox_regex_rust_is_panicking = NULL;
    size_t length = 0;
    vox_regex_append_panic_text(&length, message, message_length < 4096 ? message_length : 4096);
    if (message_length > 4096) vox_regex_append_panic_text(&length, " [truncated]", 12);
    if (filename_length) {
        vox_regex_append_panic_text(&length, " at ", 4);
        if (filename_length > 4096) {
            vox_regex_append_panic_text(&length, "[location unavailable]", 22);
        } else {
            vox_regex_append_panic_text(&length, filename, filename_length);
            char location[24];
            int count = snprintf(location, sizeof(location), ":%u:%u", line, column);
            if (count > 0)
                vox_regex_append_panic_text(&length, location,
                    (size_t)count < sizeof(location) ? (size_t)count : sizeof(location) - 1);
        }
    }
    vox_regex_rust_panic_text[length] = 0;
    (void)is_panicking();
    vox_regex_rust_is_panicking = is_panicking;
}

void ladybird_rust_panic_will_abort(void) {
    if (vox_regex_rust_is_panicking)
        fprintf(stderr, "Rust panic: %s\n", vox_regex_rust_panic_text);
}
