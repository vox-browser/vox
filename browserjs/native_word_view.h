#ifndef VOX_BROWSERJS_NATIVE_WORD_VIEW_H
#define VOX_BROWSERJS_NATIVE_WORD_VIEW_H
#include <JavaScriptCore/JavaScript.h>
#include <stdbool.h>
// A deletable, non-enumerable global Uint32Array over native words that the
// caller keeps alive for the context's lifetime. JavaScriptCore neither copies
// nor frees them.
static bool vox_jsc_install_native_word_view(void* context, const char* name, void* words,
    size_t count) {
    JSContextRef ctx = (JSContextRef)context;
    JSValueRef exception = NULL;
    JSObjectRef view = JSObjectMakeTypedArrayWithBytesNoCopy(ctx, kJSTypedArrayTypeUint32Array,
        words, count * 4, NULL, NULL, &exception);
    if (!view || exception) return false;
    JSStringRef key = JSStringCreateWithUTF8CString(name);
    JSObjectSetProperty(ctx, JSContextGetGlobalObject(ctx), key, view, kJSPropertyAttributeDontEnum,
        &exception);
    JSStringRelease(key);
    return exception == NULL;
}
#endif
