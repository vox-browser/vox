// SPDX-License-Identifier: BSD-2-Clause
#ifndef VOX_MODULE_LEXER_COPY_H
#define VOX_MODULE_LEXER_COPY_H

#include <JavaScriptCore/JavaScript.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "../platform/native_state.h"

VOX_NATIVE_STATE _Thread_local bool vox_module_lexer_copy_reported;

// Private lexer transport, never installed on the author global. JSC does not
// expose a Wasm memory's movable backing store through its public pointer API.
// Copy into an ordinary engine-owned Uint16Array, then let the captured native
// typed-array setter transfer it into Wasm memory. Keep UTF-16 code units,
// including NULs and lone surrogates; the lexer decides their meaning.
static JSValueRef vox_module_lexer_copy(JSContextRef context, JSObjectRef function,
    JSObjectRef receiver, size_t count, const JSValueRef arguments[], JSValueRef *exception)
{
    (void)function; (void)receiver; (void)exception;
    if (count != 1 || !JSValueIsString(context, arguments[0]))
        return JSValueMakeUndefined(context);
    JSValueRef ignored = NULL;
    JSStringRef source = JSValueToStringCopy(context, arguments[0], &ignored);
    if (!source || ignored) {
        if (source) JSStringRelease(source);
        return JSValueMakeUndefined(context);
    }
    size_t length = JSStringGetLength(source);
    JSObjectRef array = NULL;
    if (length <= SIZE_MAX / sizeof(JSChar)) {
        array = JSObjectMakeTypedArray(context, kJSTypedArrayTypeUint16Array, length, &ignored);
        if (!ignored && array && length) {
            const JSChar *characters = JSStringGetCharactersPtr(source);
            uint8_t *target = JSObjectGetTypedArrayBytesPtr(context, array, &ignored);
            if (ignored || !characters || !target) array = NULL;
            else {
                // No JSC call occurs while the borrowed target pointer is live.
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
                memcpy(target, characters, length * sizeof(JSChar));
#else
                // The destination Wasm memory always uses little endian.
                for (size_t i = 0; i < length; ++i) {
                    target[2 * i] = (uint8_t)characters[i];
                    target[2 * i + 1] = (uint8_t)(characters[i] >> 8);
                }
#endif
            }
        } else if (ignored) array = NULL;
    }
    JSStringRelease(source);
    if (!array) return JSValueMakeUndefined(context);
    const char *diagnostics = getenv("VOX_MODULE_LEXER_DIAGNOSTICS");
    if (!vox_module_lexer_copy_reported && diagnostics && *diagnostics) {
        vox_module_lexer_copy_reported = true;
        fprintf(stderr, "Vox module lexer UTF-16: native copy executed\n");
    }
    return array;
}

static void *vox_make_module_lexer_copy(void *context)
{
    return (void *)JSObjectMakeFunctionWithCallback((JSContextRef)context, NULL, vox_module_lexer_copy);
}

#endif
