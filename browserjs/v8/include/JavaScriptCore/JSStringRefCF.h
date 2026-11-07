// SPDX-License-Identifier: BSD-2-Clause
#ifndef VOX_V8_JAVASCRIPTCORE_JSSTRINGREFCF_H
#define VOX_V8_JAVASCRIPTCORE_JSSTRINGREFCF_H

#include <CoreFoundation/CoreFoundation.h>
#include <JavaScriptCore/JavaScript.h>

#ifdef __cplusplus
extern "C" {
#endif

JS_EXPORT JSStringRef JSStringCreateWithCFString(CFStringRef string);
JS_EXPORT CFStringRef JSStringCopyCFString(CFAllocatorRef alloc, JSStringRef string) CF_RETURNS_RETAINED;

#ifdef __cplusplus
}
#endif

#endif
