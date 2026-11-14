#pragma once
#include <JavaScriptCore/JavaScript.h>

static inline void *vox_jsc_construct_error(void *context, void *constructor,
    void *message, void **exception)
{
    JSValueRef argument = (JSValueRef)message;
    JSValueRef thrown = NULL;
    JSObjectRef result = JSObjectCallAsConstructor((JSContextRef)context,
        (JSObjectRef)constructor, 1, &argument, &thrown);
    if (exception) *exception = (void *)thrown;
    return (void *)result;
}
