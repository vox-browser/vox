// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
#ifndef VOX_SOURCE_ARRAY_BUFFER_DARWIN_H
#define VOX_SOURCE_ARRAY_BUFFER_DARWIN_H

#include "jsc_abi.h"
#include <stdlib.h>
#include <string.h>

static void vox_free_source_array_buffer(void* bytes, void* context)
{
    (void)context;
    free(bytes);
}

// ArrayBuffer::create(realm, ByteBuffer) owns a separate backing store, copies
// the ByteBuffer into it and treats allocation failure as Source MUST fatal.
// JSC owns this backing store after the ABI call and invokes its deallocator
// on either collection or a creation exception.
static void* vox_jsc_make_source_array_buffer_copy(void* context,
    void const* bytes, size_t length, void** exception)
{
    void* backing = malloc(length ? length : 1);
    if (!backing)
        abort();
    if (length)
        memcpy(backing, bytes, length);
    JSValueRef native_exception = vox_jsc_exception_value(exception);
    JSObjectRef buffer = JSObjectMakeArrayBufferWithBytesNoCopy((JSContextRef)context,
        backing, length, vox_free_source_array_buffer, NULL,
        exception ? &native_exception : NULL);
    vox_jsc_store_exception(exception, native_exception);
    return (void*)buffer;
}

#endif
