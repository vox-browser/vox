#pragma once
#include <JavaScriptCore/JavaScript.h>

static unsigned vox_forwarding_api_exceptions;
static void vox_forwarding_reset_api_exceptions(void) { vox_forwarding_api_exceptions = 0; }
static unsigned vox_forwarding_api_exception_count(void) { return vox_forwarding_api_exceptions; }
static JSValueRef vox_forwarding_observe_call(JSContextRef context, JSObjectRef function,
    JSObjectRef receiver, size_t count, const JSValueRef arguments[], JSValueRef* exception)
{
    JSValueRef value = JSObjectCallAsFunction(context, function, receiver, count, arguments, exception);
    if (exception && *exception)
        ++vox_forwarding_api_exceptions;
    return value;
}
#define JSObjectCallAsFunction vox_forwarding_observe_call
