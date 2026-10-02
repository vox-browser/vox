#pragma once
#include <JavaScriptCore/JavaScriptCore.h>

// A generated binding's platform object stores the actual owning native record.
// The private record supplies the concrete interface brand; JS prototype changes
// do not turn ordinary objects into Streams implementations.
static JSClassRef vox_native_stream_wrapper_class(void)
{
    static JSClassRef object_class;
    if (!object_class) {
        JSClassDefinition definition = kJSClassDefinitionEmpty;
        definition.className = "LibWebStreamsObject";
        object_class = JSClassCreate(&definition);
    }
    return object_class;
}

static JSObjectRef vox_make_native_stream_wrapper(JSGlobalContextRef context, void* record)
{
    return JSObjectMake(context, vox_native_stream_wrapper_class(), record);
}

static void* vox_native_stream_wrapper_record(JSContextRef context, JSValueRef value)
{
    if (!JSValueIsObjectOfClass(context, value, vox_native_stream_wrapper_class()))
        return NULL;
    return JSObjectGetPrivate((JSObjectRef)value);
}
