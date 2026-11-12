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
    JSObjectRef has;
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

static bool vox_platform_function_registry(void *source, void **operations) {
    pthread_once(&vox_platform_function_key_once, vox_platform_function_registry_make_key);
    if (!vox_platform_function_key_ready) return false;
    JSContextGroupRef group = JSContextGetGroup((JSContextRef)source);
    VoxPlatformFunctionRegistry *head = pthread_getspecific(vox_platform_function_key);
    for (VoxPlatformFunctionRegistry *item = head; item; item = item->next) {
        if (item->group != group) continue;
        operations[0] = (void *)item->add;
        operations[1] = (void *)item->has;
        return true;
    }
    // A dedicated, DOM-free realm owns the registry. Using a document's realm
    // here would keep its global object alive for the lifetime of the agent.
    JSGlobalContextRef context = JSGlobalContextCreateInGroup(group, NULL);
    if (!context) return false;
    JSStringRef source_text = JSStringCreateWithUTF8CString(
        "(()=>{'use strict';const values=new WeakSet(),add=WeakSet.prototype.add,"
        "has=WeakSet.prototype.has,apply=Reflect.apply;return["
        "value=>apply(add,values,[value]),value=>apply(has,values,[value])];})()");
    JSValueRef exception = NULL;
    JSValueRef values = JSEvaluateScript(context, source_text, NULL, NULL, 1, &exception);
    JSStringRelease(source_text);
    if (exception || !values || !JSValueIsObject(context, values)) {
        JSGlobalContextRelease(context);
        return false;
    }
    JSValueProtect(context, values);
    JSObjectRef array = JSValueToObject(context, values, &exception);
    JSValueRef add = JSObjectGetPropertyAtIndex(context, array, 0, &exception);
    JSValueRef has = JSObjectGetPropertyAtIndex(context, array, 1, &exception);
    if (exception || !JSValueIsObject(context, add) || !JSValueIsObject(context, has)) {
        JSValueUnprotect(context, values);
        JSGlobalContextRelease(context);
        return false;
    }
    VoxPlatformFunctionRegistry *registry = calloc(1, sizeof(*registry));
    if (!registry) {
        JSValueUnprotect(context, values);
        JSGlobalContextRelease(context);
        return false;
    }
    registry->group = group;
    registry->context = context;
    registry->operations = values;
    registry->add = JSValueToObject(context, add, NULL);
    registry->has = JSValueToObject(context, has, NULL);
    registry->next = head;
    if (pthread_setspecific(vox_platform_function_key, registry)) {
        JSValueUnprotect(context, values);
        JSGlobalContextRelease(context);
        free(registry);
        return false;
    }
    operations[0] = (void *)registry->add;
    operations[1] = (void *)registry->has;
    return true;
}
