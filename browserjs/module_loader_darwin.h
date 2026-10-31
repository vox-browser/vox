// SPDX-License-Identifier: BSD-2-Clause
#pragma once
#include <JavaScriptCore/JavaScript.h>
void *vox_module_loader_install(JSGlobalContextRef, JSObjectRef, JSObjectRef);
void vox_module_loader_close(JSGlobalContextRef, void *);
JSValueRef vox_module_loader_evaluate(JSGlobalContextRef, const char *, size_t, JSValueRef *);
JSValueRef vox_module_loader_supply(JSGlobalContextRef, JSObjectRef, const char *, size_t, const char *, size_t, JSValueRef *);
