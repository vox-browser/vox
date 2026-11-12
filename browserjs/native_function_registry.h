// Platform function identity belongs to an agent, including calls made through
// another realm's Function.prototype.toString. Weak keys must not retain the
// documents which installed those functions.
#pragma once
#include <JavaScriptCore/JavaScript.h>
#include <pthread.h>
#include <stdlib.h>
#include "../platform/native_state.h"

typedef struct VoxPlatformFunctionRegistry {
    JSContextGroupRef group;
    JSGlobalContextRef context;
    JSValueRef operations;
    JSObjectRef add;
    JSObjectRef lookup;
    JSObjectRef register_formatter;
    JSObjectRef original;
    struct VoxPlatformFunctionRegistry *next;
} VoxPlatformFunctionRegistry;

VOX_NATIVE_STATE pthread_once_t vox_platform_function_key_once VOX_NATIVE_STATE_INIT(PTHREAD_ONCE_INIT);
VOX_NATIVE_STATE pthread_key_t vox_platform_function_key;
VOX_NATIVE_STATE int vox_platform_function_key_ready;

static void vox_platform_function_registry_destroy(void *value) {
    VoxPlatformFunctionRegistry *registry = value;
    while (registry) {
        VoxPlatformFunctionRegistry *next = registry->next;
        JSValueUnprotect(registry->context, registry->operations);
        JSGlobalContextRelease(registry->context);
        free(registry);
        registry = next;
    }
}

static void vox_platform_function_registry_make_key(void) {
    vox_platform_function_key_ready = pthread_key_create(&vox_platform_function_key,
        vox_platform_function_registry_destroy) == 0;
}

static VoxPlatformFunctionRegistry *vox_platform_function_registry(void *source) {
    pthread_once(&vox_platform_function_key_once, vox_platform_function_registry_make_key);
    if (!vox_platform_function_key_ready) return NULL;
    JSContextGroupRef group = JSContextGetGroup((JSContextRef)source);
    VoxPlatformFunctionRegistry *head = pthread_getspecific(vox_platform_function_key);
    for (VoxPlatformFunctionRegistry *item = head; item; item = item->next) {
        if (item->group != group) continue;
        return item;
    }
    // A dedicated, DOM-free realm owns the registry. Using a document's realm
    // here would keep its global object alive for the lifetime of the agent.
    JSGlobalContextRef context = JSGlobalContextCreateInGroup(group, NULL);
    if (!context) return NULL;
    JSStringRef source_text = JSStringCreateWithUTF8CString(
        "(()=>{'use strict';const sources=new WeakMap(),originals=new WeakMap(),"
        "set=WeakMap.prototype.set,get=WeakMap.prototype.get,has=WeakMap.prototype.has,apply=Reflect.apply;return["
        "(value,text)=>{if(!apply(has,sources,[value]))apply(set,sources,[value,text]);},"
        "value=>apply(get,sources,[value]),"
        "(value,original)=>apply(set,originals,[value,original]),"
        "value=>apply(get,originals,[value])];})()");
    JSValueRef exception = NULL;
    JSValueRef values = JSEvaluateScript(context, source_text, NULL, NULL, 1, &exception);
    JSStringRelease(source_text);
    if (exception || !values || !JSValueIsObject(context, values)) {
        JSGlobalContextRelease(context);
        return NULL;
    }
    JSValueProtect(context, values);
    JSObjectRef array = JSValueToObject(context, values, &exception);
    JSValueRef add = JSObjectGetPropertyAtIndex(context, array, 0, &exception);
    JSValueRef lookup = JSObjectGetPropertyAtIndex(context, array, 1, &exception);
    JSValueRef register_formatter = JSObjectGetPropertyAtIndex(context, array, 2, &exception);
    JSValueRef original = JSObjectGetPropertyAtIndex(context, array, 3, &exception);
    if (exception || !JSValueIsObject(context, add) || !JSValueIsObject(context, lookup) || !JSValueIsObject(context, register_formatter) || !JSValueIsObject(context, original)) {
        JSValueUnprotect(context, values);
        JSGlobalContextRelease(context);
        return NULL;
    }
    VoxPlatformFunctionRegistry *registry = calloc(1, sizeof(*registry));
    if (!registry) {
        JSValueUnprotect(context, values);
        JSGlobalContextRelease(context);
        return NULL;
    }
    registry->group = group;
    registry->context = context;
    registry->operations = values;
    registry->add = JSValueToObject(context, add, NULL);
    registry->lookup = JSValueToObject(context, lookup, NULL);
    registry->register_formatter = JSValueToObject(context, register_formatter, NULL);
    registry->original = JSValueToObject(context, original, NULL);
    registry->next = head;
    if (pthread_setspecific(vox_platform_function_key, registry)) {
        JSValueUnprotect(context, values);
        JSGlobalContextRelease(context);
        free(registry);
        return NULL;
    }
    return registry;
}


// The callback has no Runtime record: retained formatters continue to work
// after their originating document closes. Both maps have weak keys, so the
// agent does not keep discarded documents alive merely for source formatting.
static JSValueRef vox_platform_function_to_string(JSContextRef context,
    JSObjectRef function, JSObjectRef receiver, size_t count,
    const JSValueRef arguments[], JSValueRef *exception)
{
    (void)count; (void)arguments;
    VoxPlatformFunctionRegistry *registry = vox_platform_function_registry((void *)context);
    if (!registry) return JSValueMakeUndefined(context);
    JSValueRef value = (JSValueRef)receiver;
    JSValueRef source = JSObjectCallAsFunction(context, registry->lookup, NULL,
        1, &value, exception);
    if (exception && *exception) return JSValueMakeUndefined(context);
    if (source && JSValueIsString(context, source)) return source;
    value = (JSValueRef)function;
    JSValueRef original = JSObjectCallAsFunction(context, registry->original, NULL,
        1, &value, exception);
    if ((exception && *exception) || !original || !JSValueIsObject(context, original))
        return JSValueMakeUndefined(context);
    return JSObjectCallAsFunction(context, (JSObjectRef)original, receiver,
        0, NULL, exception);
}

static bool vox_install_platform_function_source(void *opaque_context,
    void *opaque_factory, void **opaque_exception)
{
    JSContextRef context = (JSContextRef)opaque_context;
    VoxPlatformFunctionRegistry *registry = vox_platform_function_registry(opaque_context);
    if (!registry) return false;
    JSValueRef exception = NULL;
    JSObjectRef global = JSContextGetGlobalObject(context);
    JSStringRef key = JSStringCreateWithUTF8CString("Function");
    JSValueRef constructor = JSObjectGetProperty(context, global, key, &exception);
    JSStringRelease(key);
    if (exception) goto failed;
    key = JSStringCreateWithUTF8CString("prototype");
    JSValueRef prototype = JSObjectGetProperty(context, (JSObjectRef)constructor, key, &exception);
    JSStringRelease(key);
    if (exception) goto failed;
    key = JSStringCreateWithUTF8CString("toString");
    JSValueRef original = JSObjectGetProperty(context, (JSObjectRef)prototype, key, &exception);
    JSStringRelease(key);
    if (exception) goto failed;
    JSValueRef argument = (JSValueRef)registry->add;
    JSObjectCallAsFunction(context, (JSObjectRef)opaque_factory, global, 1, &argument, &exception);
    if (exception) goto failed;
    key = JSStringCreateWithUTF8CString("toString");
    JSObjectRef formatter = JSObjectMakeFunctionWithCallback(context, key, vox_platform_function_to_string);
    JSValueRef pair[2] = {(JSValueRef)formatter, original};
    JSObjectCallAsFunction(context, registry->register_formatter, NULL, 2, pair, &exception);
    if (!exception) JSObjectSetProperty(context, (JSObjectRef)prototype, key,
        formatter, kJSPropertyAttributeDontEnum, &exception);
    JSStringRelease(key);
    if (!exception) return true;
failed:
    if (opaque_exception) *opaque_exception = (void *)exception;
    return false;
}
