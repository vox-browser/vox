// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
#pragma once
#include <JavaScriptCore/JavaScript.h>
#include "host_function_darwin.h"

// This resolver holds no Runtime or V closure. A retained Blob method can
// resolve its live receiver after the method's original runtime is closed.
extern void *vox_jsc_blob_operation_resolver(void *, void *, void *, size_t, void **, void **);

static JSValueRef vox_blob_operation_resolver_trampoline(JSContextRef context,
    JSObjectRef function, JSObjectRef receiver, size_t count,
    JSValueRef const arguments[], JSValueRef *exception)
{
    return vox_jsc_invoke_v_host_function(vox_jsc_blob_operation_resolver,
        context, function, receiver, count, arguments, exception);
}

static void *vox_make_blob_operation_resolver(void *context)
{
    return (void *)JSObjectMakeFunctionWithCallback((JSContextRef)context, NULL,
        vox_blob_operation_resolver_trampoline);
}
