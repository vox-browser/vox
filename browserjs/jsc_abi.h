// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
#ifndef VOX_BROWSERJS_JSC_ABI_H
#define VOX_BROWSERJS_JSC_ABI_H

#include <JavaScriptCore/JavaScript.h>
#include <stdint.h>
#include <stdlib.h>

// V keeps engine handles opaque. A void* handle converts to a native handle,
// but an array or output slot of void* is not storage for JSValueRef. Keep those
// native types here, including JSValueRef's const qualifier, and copy handles
// across the boundary individually. Do not cast void** to a native pointer.
enum { vox_jsc_inline_argument_count = 8 };

static inline JSValueRef vox_jsc_exception_value(void** exception)
{
    return exception ? (JSValueRef)*exception : NULL;
}

static inline void vox_jsc_store_exception(void** exception, JSValueRef value)
{
    if (exception)
        *exception = (void*)value;
}

static inline void* vox_jsc_allocate_arguments(size_t count, size_t element_size)
{
    // Host allocation failures are fatal, as in source_array_buffer_darwin.h.
    if (count > SIZE_MAX / element_size)
        abort();
    void* allocation = malloc(count * element_size);
    if (!allocation)
        abort();
    return allocation;
}

static inline JSValueRef* vox_jsc_value_arguments(size_t count,
    void* const* arguments, JSValueRef* inline_arguments)
{
    if (!count)
        return NULL;
    JSValueRef* native_arguments = count <= vox_jsc_inline_argument_count
        ? inline_arguments : vox_jsc_allocate_arguments(count, sizeof(JSValueRef));
    for (size_t i = 0; i < count; ++i)
        native_arguments[i] = (JSValueRef)arguments[i];
    return native_arguments;
}

static inline JSStringRef* vox_jsc_string_arguments(size_t count,
    void* const* arguments, JSStringRef* inline_arguments)
{
    if (!count)
        return NULL;
    JSStringRef* native_arguments = count <= vox_jsc_inline_argument_count
        ? inline_arguments : vox_jsc_allocate_arguments(count, sizeof(JSStringRef));
    for (size_t i = 0; i < count; ++i)
        native_arguments[i] = (JSStringRef)arguments[i];
    return native_arguments;
}

static inline void vox_jsc_free_arguments(size_t count, void* arguments)
{
    if (count > vox_jsc_inline_argument_count)
        free(arguments);
}

static inline void* vox_jsc_JSEvaluateScript(void* context, void* script,
    void* this_object, void* source_url, int starting_line_number, void** exception)
{
    JSValueRef native_exception = vox_jsc_exception_value(exception);
    JSValueRef value = JSEvaluateScript((JSContextRef)context, (JSStringRef)script,
        (JSObjectRef)this_object, (JSStringRef)source_url, starting_line_number,
        exception ? &native_exception : NULL);
    vox_jsc_store_exception(exception, native_exception);
    return (void*)value;
}

static inline bool vox_jsc_JSCheckScriptSyntax(void* context, void* script,
    void* source_url, int starting_line_number, void** exception)
{
    JSValueRef native_exception = vox_jsc_exception_value(exception);
    bool valid = JSCheckScriptSyntax((JSContextRef)context, (JSStringRef)script,
        (JSStringRef)source_url, starting_line_number,
        exception ? &native_exception : NULL);
    vox_jsc_store_exception(exception, native_exception);
    return valid;
}

static inline void* vox_jsc_JSValueToStringCopy(void* context, void* value,
    void** exception)
{
    JSValueRef native_exception = vox_jsc_exception_value(exception);
    JSStringRef result = JSValueToStringCopy((JSContextRef)context, (JSValueRef)value,
        exception ? &native_exception : NULL);
    vox_jsc_store_exception(exception, native_exception);
    return (void*)result;
}

static inline double vox_jsc_JSValueToNumber(void* context, void* value,
    void** exception)
{
    JSValueRef native_exception = vox_jsc_exception_value(exception);
    double result = JSValueToNumber((JSContextRef)context, (JSValueRef)value,
        exception ? &native_exception : NULL);
    vox_jsc_store_exception(exception, native_exception);
    return result;
}

static inline void* vox_jsc_JSValueToObject(void* context, void* value,
    void** exception)
{
    JSValueRef native_exception = vox_jsc_exception_value(exception);
    JSObjectRef result = JSValueToObject((JSContextRef)context, (JSValueRef)value,
        exception ? &native_exception : NULL);
    vox_jsc_store_exception(exception, native_exception);
    return (void*)result;
}

static inline int vox_jsc_JSValueGetTypedArrayType(void* context, void* value,
    void** exception)
{
    JSValueRef native_exception = vox_jsc_exception_value(exception);
    JSTypedArrayType result = JSValueGetTypedArrayType((JSContextRef)context,
        (JSValueRef)value, exception ? &native_exception : NULL);
    vox_jsc_store_exception(exception, native_exception);
    return (int)result;
}

static inline void* vox_jsc_JSObjectGetProperty(void* context, void* object,
    void* property_name, void** exception)
{
    JSValueRef native_exception = vox_jsc_exception_value(exception);
    JSValueRef value = JSObjectGetProperty((JSContextRef)context, (JSObjectRef)object,
        (JSStringRef)property_name, exception ? &native_exception : NULL);
    vox_jsc_store_exception(exception, native_exception);
    return (void*)value;
}

static inline void* vox_jsc_JSObjectGetPropertyAtIndex(void* context, void* object,
    unsigned index, void** exception)
{
    JSValueRef native_exception = vox_jsc_exception_value(exception);
    JSValueRef value = JSObjectGetPropertyAtIndex((JSContextRef)context,
        (JSObjectRef)object, index, exception ? &native_exception : NULL);
    vox_jsc_store_exception(exception, native_exception);
    return (void*)value;
}

static inline void vox_jsc_JSObjectSetProperty(void* context, void* object,
    void* property_name, void* value, unsigned attributes, void** exception)
{
    JSValueRef native_exception = vox_jsc_exception_value(exception);
    JSObjectSetProperty((JSContextRef)context, (JSObjectRef)object,
        (JSStringRef)property_name, (JSValueRef)value, (JSPropertyAttributes)attributes,
        exception ? &native_exception : NULL);
    vox_jsc_store_exception(exception, native_exception);
}

static inline void* vox_jsc_JSObjectMakeTypedArray(void* context, int array_type,
    size_t length, void** exception)
{
    JSValueRef native_exception = vox_jsc_exception_value(exception);
    JSObjectRef value = JSObjectMakeTypedArray((JSContextRef)context,
        (JSTypedArrayType)array_type, length, exception ? &native_exception : NULL);
    vox_jsc_store_exception(exception, native_exception);
    return (void*)value;
}

static inline void* vox_jsc_JSObjectMakeTypedArrayWithArrayBuffer(void* context,
    int array_type, void* buffer, void** exception)
{
    JSValueRef native_exception = vox_jsc_exception_value(exception);
    JSObjectRef value = JSObjectMakeTypedArrayWithArrayBuffer((JSContextRef)context,
        (JSTypedArrayType)array_type, (JSObjectRef)buffer,
        exception ? &native_exception : NULL);
    vox_jsc_store_exception(exception, native_exception);
    return (void*)value;
}

static inline void* vox_jsc_JSObjectGetTypedArrayBuffer(void* context, void* object,
    void** exception)
{
    JSValueRef native_exception = vox_jsc_exception_value(exception);
    JSObjectRef value = JSObjectGetTypedArrayBuffer((JSContextRef)context,
        (JSObjectRef)object, exception ? &native_exception : NULL);
    vox_jsc_store_exception(exception, native_exception);
    return (void*)value;
}

static inline void* vox_jsc_JSObjectGetArrayBufferBytesPtr(void* context,
    void* object, void** exception)
{
    JSValueRef native_exception = vox_jsc_exception_value(exception);
    void* bytes = JSObjectGetArrayBufferBytesPtr((JSContextRef)context,
        (JSObjectRef)object, exception ? &native_exception : NULL);
    vox_jsc_store_exception(exception, native_exception);
    return bytes;
}

static inline void* vox_jsc_JSObjectGetTypedArrayBytesPtr(void* context,
    void* object, void** exception)
{
    JSValueRef native_exception = vox_jsc_exception_value(exception);
    void* bytes = JSObjectGetTypedArrayBytesPtr((JSContextRef)context,
        (JSObjectRef)object, exception ? &native_exception : NULL);
    vox_jsc_store_exception(exception, native_exception);
    return bytes;
}

static inline size_t vox_jsc_JSObjectGetArrayBufferByteLength(void* context,
    void* object, void** exception)
{
    JSValueRef native_exception = vox_jsc_exception_value(exception);
    size_t length = JSObjectGetArrayBufferByteLength((JSContextRef)context,
        (JSObjectRef)object, exception ? &native_exception : NULL);
    vox_jsc_store_exception(exception, native_exception);
    return length;
}

static inline size_t vox_jsc_JSObjectGetTypedArrayByteLength(void* context,
    void* object, void** exception)
{
    JSValueRef native_exception = vox_jsc_exception_value(exception);
    size_t length = JSObjectGetTypedArrayByteLength((JSContextRef)context,
        (JSObjectRef)object, exception ? &native_exception : NULL);
    vox_jsc_store_exception(exception, native_exception);
    return length;
}

static inline size_t vox_jsc_JSObjectGetTypedArrayByteOffset(void* context,
    void* object, void** exception)
{
    JSValueRef native_exception = vox_jsc_exception_value(exception);
    size_t offset = JSObjectGetTypedArrayByteOffset((JSContextRef)context,
        (JSObjectRef)object, exception ? &native_exception : NULL);
    vox_jsc_store_exception(exception, native_exception);
    return offset;
}

static inline void* vox_jsc_JSObjectMakeDeferredPromise(void* context,
    void** resolve, void** reject, void** exception)
{
    JSObjectRef native_resolve = resolve ? (JSObjectRef)*resolve : NULL;
    JSObjectRef native_reject = reject ? (JSObjectRef)*reject : NULL;
    JSValueRef native_exception = vox_jsc_exception_value(exception);
    JSObjectRef promise = JSObjectMakeDeferredPromise((JSContextRef)context,
        resolve ? &native_resolve : NULL, reject ? &native_reject : NULL,
        exception ? &native_exception : NULL);
    if (resolve)
        *resolve = (void*)native_resolve;
    if (reject)
        *reject = (void*)native_reject;
    vox_jsc_store_exception(exception, native_exception);
    return (void*)promise;
}

static inline void* vox_jsc_JSObjectMakeArray(void* context, size_t count,
    void* const* arguments, void** exception)
{
    JSValueRef inline_arguments[vox_jsc_inline_argument_count];
    JSValueRef* native_arguments = vox_jsc_value_arguments(count, arguments, inline_arguments);
    JSValueRef native_exception = vox_jsc_exception_value(exception);
    JSObjectRef value = JSObjectMakeArray((JSContextRef)context, count, native_arguments,
        exception ? &native_exception : NULL);
    vox_jsc_free_arguments(count, native_arguments);
    vox_jsc_store_exception(exception, native_exception);
    return (void*)value;
}

static inline void* vox_jsc_JSObjectMakeDate(void* context, size_t count,
    void* const* arguments, void** exception)
{
    JSValueRef inline_arguments[vox_jsc_inline_argument_count];
    JSValueRef* native_arguments = vox_jsc_value_arguments(count, arguments, inline_arguments);
    JSValueRef native_exception = vox_jsc_exception_value(exception);
    JSObjectRef value = JSObjectMakeDate((JSContextRef)context, count, native_arguments,
        exception ? &native_exception : NULL);
    vox_jsc_free_arguments(count, native_arguments);
    vox_jsc_store_exception(exception, native_exception);
    return (void*)value;
}

static inline void* vox_jsc_JSObjectMakeError(void* context, size_t count,
    void* const* arguments, void** exception)
{
    JSValueRef inline_arguments[vox_jsc_inline_argument_count];
    JSValueRef* native_arguments = vox_jsc_value_arguments(count, arguments, inline_arguments);
    JSValueRef native_exception = vox_jsc_exception_value(exception);
    JSObjectRef value = JSObjectMakeError((JSContextRef)context, count, native_arguments,
        exception ? &native_exception : NULL);
    vox_jsc_free_arguments(count, native_arguments);
    vox_jsc_store_exception(exception, native_exception);
    return (void*)value;
}

static inline void* vox_jsc_JSObjectCallAsFunction(void* context, void* function,
    void* receiver, size_t count, void* const* arguments, void** exception)
{
    JSValueRef inline_arguments[vox_jsc_inline_argument_count];
    JSValueRef* native_arguments = vox_jsc_value_arguments(count, arguments, inline_arguments);
    JSValueRef native_exception = vox_jsc_exception_value(exception);
    JSValueRef value = JSObjectCallAsFunction((JSContextRef)context, (JSObjectRef)function,
        (JSObjectRef)receiver, count, native_arguments,
        exception ? &native_exception : NULL);
    vox_jsc_free_arguments(count, native_arguments);
    vox_jsc_store_exception(exception, native_exception);
    return (void*)value;
}

static inline void* vox_jsc_JSObjectMakeFunction(void* context, void* name,
    unsigned count, void* const* parameters, void* body, void* source_url,
    int starting_line_number, void** exception)
{
    JSStringRef inline_parameters[vox_jsc_inline_argument_count];
    JSStringRef* native_parameters = vox_jsc_string_arguments(count, parameters, inline_parameters);
    JSValueRef native_exception = vox_jsc_exception_value(exception);
    JSObjectRef value = JSObjectMakeFunction((JSContextRef)context, (JSStringRef)name,
        count, native_parameters, (JSStringRef)body, (JSStringRef)source_url,
        starting_line_number, exception ? &native_exception : NULL);
    vox_jsc_free_arguments(count, native_parameters);
    vox_jsc_store_exception(exception, native_exception);
    return (void*)value;
}

static inline void* vox_jsc_JSValueMakeUndefined(void* context)
{
    return (void*)JSValueMakeUndefined((JSContextRef)context);
}

static inline void* vox_jsc_JSValueMakeNull(void* context)
{
    return (void*)JSValueMakeNull((JSContextRef)context);
}

static inline void* vox_jsc_JSValueMakeBoolean(void* context, bool value)
{
    return (void*)JSValueMakeBoolean((JSContextRef)context, value);
}

static inline void* vox_jsc_JSValueMakeNumber(void* context, double value)
{
    return (void*)JSValueMakeNumber((JSContextRef)context, value);
}

static inline void* vox_jsc_JSValueMakeString(void* context, void* value)
{
    return (void*)JSValueMakeString((JSContextRef)context, (JSStringRef)value);
}

static inline void* vox_jsc_JSValueMakeFromJSONString(void* context, void* value)
{
    return (void*)JSValueMakeFromJSONString((JSContextRef)context, (JSStringRef)value);
}

static inline void vox_jsc_copy_string_characters(void* value,
    uint16_t* destination, size_t count)
{
    // Keep JSC's borrowed character storage const. The V callers allocate their
    // own code-unit buffer and pass its length, preserving lone surrogates.
    const JSChar* characters = JSStringGetCharactersPtr((JSStringRef)value);
    for (size_t i = 0; i < count; ++i)
        destination[i] = characters[i];
}

#endif
