#pragma once
#include "jsc_abi.h"

// These exported V entrypoints deliberately use opaque handles. JavaScriptCore
// receives only the native-signature trampolines below, never these functions.
extern void* vox_jsc_host_function(void*, void*, void*, size_t, void**, void**);
extern void* vox_jsc_value_host_function(void*, void*, void*, size_t, void**, void**);
extern void* vox_jsc_native_value_host_function(void*, void*, void*, size_t, void**, void**);

typedef void* (*VoxJSHostCallback)(void*, void*, void*, size_t, void**, void**);

static JSValueRef vox_jsc_invoke_v_host_function(VoxJSHostCallback callback,
    JSContextRef context, JSObjectRef function, JSObjectRef receiver,
    size_t count, JSValueRef const arguments[], JSValueRef* exception)
{
    void* local_arguments[8];
    void** opaque_arguments = local_arguments;
    if (count > sizeof(local_arguments) / sizeof(local_arguments[0])) {
        if (count > SIZE_MAX / sizeof(*opaque_arguments))
            abort();
        opaque_arguments = malloc(count * sizeof(*opaque_arguments));
        if (!opaque_arguments)
            abort();
    }
    for (size_t i = 0; i < count; ++i)
        opaque_arguments[i] = (void*)arguments[i];
    void* opaque_exception = exception ? (void*)*exception : NULL;
    void* result = callback((void*)context, (void*)function, (void*)receiver,
        count, opaque_arguments, &opaque_exception);
    if (opaque_arguments != local_arguments)
        free(opaque_arguments);
    if (exception)
        *exception = (JSValueRef)opaque_exception;
    return (JSValueRef)result;
}

static JSValueRef vox_jsc_host_function_trampoline(JSContextRef context,
    JSObjectRef function, JSObjectRef receiver, size_t count,
    JSValueRef const arguments[], JSValueRef* exception)
{
    return vox_jsc_invoke_v_host_function(vox_jsc_host_function,
        context, function, receiver, count, arguments, exception);
}

static JSValueRef vox_jsc_value_host_function_trampoline(JSContextRef context,
    JSObjectRef function, JSObjectRef receiver, size_t count,
    JSValueRef const arguments[], JSValueRef* exception)
{
    return vox_jsc_invoke_v_host_function(vox_jsc_value_host_function,
        context, function, receiver, count, arguments, exception);
}

static JSValueRef vox_jsc_native_value_host_function_trampoline(JSContextRef context,
    JSObjectRef function, JSObjectRef receiver, size_t count,
    JSValueRef const arguments[], JSValueRef* exception)
{
    return vox_jsc_invoke_v_host_function(vox_jsc_native_value_host_function,
        context, function, receiver, count, arguments, exception);
}

static JSObjectRef vox_make_js_host_function_with_callback(JSGlobalContextRef context,
    void* record, JSObjectCallAsFunctionCallback callback)
{
    JSClassDefinition definition = kJSClassDefinitionEmpty;
    definition.callAsFunction = callback;
    JSClassRef object_class = JSClassCreate(&definition);
    JSObjectRef function = JSObjectMake(context, object_class, record);
    JSClassRelease(object_class);
    return function;
}

static bool vox_install_js_host_function_with_callback(JSGlobalContextRef context,
    char const* name, void* record, JSObjectCallAsFunctionCallback callback)
{
    JSObjectRef function = vox_make_js_host_function_with_callback(context, record, callback);
    JSStringRef property_name = JSStringCreateWithUTF8CString(name);
    JSValueRef exception = NULL;
    JSObjectSetProperty(context, JSContextGetGlobalObject(context), property_name, function,
        kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete, &exception);
    JSStringRelease(property_name);
    return !exception;
}

static bool vox_install_js_host_function(JSGlobalContextRef context,
    char const* name, void* record)
{
    return vox_install_js_host_function_with_callback(context, name, record,
        vox_jsc_host_function_trampoline);
}

static bool vox_install_js_value_host_function(JSGlobalContextRef context,
    char const* name, void* record)
{
    return vox_install_js_host_function_with_callback(context, name, record,
        vox_jsc_value_host_function_trampoline);
}

static void* vox_make_js_value_host_function(JSGlobalContextRef context, void* record)
{
    return (void*)vox_make_js_host_function_with_callback(context, record,
        vox_jsc_value_host_function_trampoline);
}

static void* vox_make_js_native_value_host_function(JSGlobalContextRef context, JSStringRef name)
{
    return (void*)JSObjectMakeFunctionWithCallback(context, name,
        vox_jsc_native_value_host_function_trampoline);
}
