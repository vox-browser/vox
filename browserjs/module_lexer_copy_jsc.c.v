// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import os

#include "module_lexer_copy.h"

fn C.vox_make_module_lexer_copy(voidptr) voidptr

const retain_js_module_lexer_copy = os.getenv('VOX_RETAIN_JS_MODULE_LEXER_COPY') != ''

fn (mut runtime Runtime) module_lexer_copy_function() !voidptr {
	if retain_js_module_lexer_copy { return C.vox_jsc_JSValueMakeUndefined(runtime.context) }
	return runtime.retain_javascript_value(C.vox_make_module_lexer_copy(runtime.context))
}
