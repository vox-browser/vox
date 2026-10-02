#pragma once
#include <JavaScriptCore/JavaScriptCore.h>

static JSClassRef vox_native_abort_wrapper_class(void)
{
    static JSClassRef object_class;
    if (!object_class) {
        JSClassDefinition definition = kJSClassDefinitionEmpty;
        definition.className = "LibWebAbortObject";
        object_class = JSClassCreate(&definition);
    }
    return object_class;
}

static JSObjectRef vox_make_native_abort_wrapper(JSGlobalContextRef context, void* record)
{
    return JSObjectMake(context, vox_native_abort_wrapper_class(), record);
}

static void* vox_native_abort_wrapper_record(JSContextRef context, JSValueRef value)
{
    if (!JSValueIsObjectOfClass(context, value, vox_native_abort_wrapper_class()))
        return NULL;
    return JSObjectGetPrivate((JSObjectRef)value);
}
