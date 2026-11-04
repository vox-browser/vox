module browserjs

import libjs
import os

const disable_primitive_url_string_conversion = os.getenv('VOX_DISABLE_PRIMITIVE_URL_STRING_CONVERSION') != ''
const primitive_url_string_conversion_diagnostics = os.getenv('VOX_PRIMITIVE_URL_STRING_CONVERSION_DIAGNOSTICS') != ''

__global primitive_url_string_conversion_reported bool

// A primitive string is already the result of DOMString conversion. Avoid a
// nested engine call and argument array for that case.
// Other inputs must still use ECMAScript ToString, including its string hint,
// Symbol rejection and original exceptions. Preserve raw UTF-16 here: only
// callers requesting USVString replace lone surrogates.
fn (runtime &Runtime) url_binding_dom_string(converter voidptr, value voidptr) !libjs.Utf16String {
	runtime.require_javascript_value_context()!
	if !disable_primitive_url_string_conversion && value != unsafe { nil }
		&& C.JSValueIsString(runtime.context, value) {
		if primitive_url_string_conversion_diagnostics && !primitive_url_string_conversion_reported {
			primitive_url_string_conversion_reported = true
			eprintln('Vox URL string conversion: projected primitive without engine callback')
		}
		return runtime.native_utf16_string(value)
	}
	actual := runtime.call_javascript_function(converter,
		C.vox_jsc_JSValueMakeUndefined(runtime.context), [value])!
	return runtime.native_utf16_string(actual)
}
