#pragma once
#include "jsc_abi.h"

static unsigned vox_forwarding_api_exceptions;
static void vox_forwarding_reset_api_exceptions(void) { vox_forwarding_api_exceptions = 0; }
static unsigned vox_forwarding_api_exception_count(void) { return vox_forwarding_api_exceptions; }
static void* vox_forwarding_observe_call(void* context, void* function,
    void* receiver, size_t count, void* const* arguments, void** exception)
{
    void* value = vox_jsc_JSObjectCallAsFunction(context, function, receiver, count, arguments, exception);
    if (exception && *exception)
        ++vox_forwarding_api_exceptions;
    return value;
}
static void* vox_forwarding_observe_receiver_call(void* context, void* call,
    void* function, void* receiver, size_t count, void* const* arguments, void** exception)
{
    void* value = vox_jsc_call_with_receiver_argument(context, call, function,
        receiver, count, arguments, exception);
    if (exception && *exception)
        ++vox_forwarding_api_exceptions;
    return value;
}
#define vox_jsc_JSObjectCallAsFunction vox_forwarding_observe_call
#define vox_jsc_call_with_receiver_argument vox_forwarding_observe_receiver_call
