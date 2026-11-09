#pragma once
#if defined(__APPLE__)
#include <JavaScriptCore/JavaScript.h>
extern void JSGlobalContextSetEvalEnabled(JSGlobalContextRef, bool, JSStringRef);
static inline void vox_jsc_set_eval_enabled(void *context, bool enabled) {
    JSStringRef message = JSStringCreateWithUTF8CString("Blocked by Content Security Policy");
    JSGlobalContextSetEvalEnabled((JSGlobalContextRef)context, enabled, message);
    JSStringRelease(message);
}
#endif
