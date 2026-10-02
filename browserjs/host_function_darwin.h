#pragma once
#include <JavaScriptCore/JavaScriptCore.h>

static bool vox_install_js_host_function(JSGlobalContextRef context, char const* name, void* record, JSObjectCallAsFunctionCallback callback)
{
    JSClassDefinition definition = kJSClassDefinitionEmpty;
    definition.callAsFunction = callback;
    JSClassRef object_class = JSClassCreate(&definition);
    JSObjectRef function = JSObjectMake(context, object_class, record);
    JSClassRelease(object_class);
    JSStringRef property_name = JSStringCreateWithUTF8CString(name);
    JSValueRef exception = NULL;
    JSObjectSetProperty(context, JSContextGetGlobalObject(context), property_name, function,
        kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete, &exception);
    JSStringRelease(property_name);
    return !exception;
}
