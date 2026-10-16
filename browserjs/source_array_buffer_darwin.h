// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
#ifndef VOX_SOURCE_ARRAY_BUFFER_DARWIN_H
#define VOX_SOURCE_ARRAY_BUFFER_DARWIN_H

#include <JavaScriptCore/JavaScript.h>
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
static JSObjectRef vox_make_source_array_buffer_copy(JSContextRef context,
    void const* bytes, size_t length, JSValueRef* exception)
{
    void* backing = malloc(length ? length : 1);
    if (!backing)
        abort();
    if (length)
        memcpy(backing, bytes, length);
    return JSObjectMakeArrayBufferWithBytesNoCopy(context, backing, length,
        vox_free_source_array_buffer, NULL, exception);
}

#endif
