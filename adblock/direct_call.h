#ifndef VOX_ADBLOCK_DIRECT_CALL_H
#define VOX_ADBLOCK_DIRECT_CALL_H
#include <JavaScriptCore/JavaScript.h>
// Call the global function `name` with the elements of the JSON array
// `arguments_json` as its arguments. Returns NULL when the arguments are not
// a JSON array of at most eight values, the global is not a function, or the
// call throws: the caller then evaluates the original call as a script, which
// reports the same error.
static JSValueRef vox_adblock_call_with_json_arguments(void* context, const char* name,
    JSStringRef arguments_json) {
    JSContextRef ctx = (JSContextRef)context;
    JSValueRef array_value = JSValueMakeFromJSONString(ctx, arguments_json);
    if (!array_value || !JSValueIsObject(ctx, array_value)) return NULL;
    JSValueRef exception = NULL;
    JSObjectRef array = JSValueToObject(ctx, array_value, &exception);
    if (exception || !array) return NULL;
    JSStringRef length_key = JSStringCreateWithUTF8CString("length");
    JSValueRef length_value = JSObjectGetProperty(ctx, array, length_key, &exception);
    JSStringRelease(length_key);
    if (exception) return NULL;
    double length = JSValueToNumber(ctx, length_value, &exception);
    if (exception || !(length >= 0 && length <= 8) || length != (double)(size_t)length) return NULL;
    JSStringRef key = JSStringCreateWithUTF8CString(name);
    JSValueRef function_value = JSObjectGetProperty(ctx, JSContextGetGlobalObject(ctx), key, &exception);
    JSStringRelease(key);
    if (exception || !function_value || !JSValueIsObject(ctx, function_value)) return NULL;
    JSObjectRef function = JSValueToObject(ctx, function_value, &exception);
    if (exception || !function || !JSObjectIsFunction(ctx, function)) return NULL;
    JSValueRef argv[8];
    size_t argc = (size_t)length;
    for (size_t index = 0; index < argc; ++index) {
        argv[index] = JSObjectGetPropertyAtIndex(ctx, array, (unsigned)index, &exception);
        if (exception) return NULL;
    }
    JSValueRef result = JSObjectCallAsFunction(ctx, function, NULL, argc, argv, &exception);
    return exception ? NULL : result;
}
#endif
