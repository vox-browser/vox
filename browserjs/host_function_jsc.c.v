module browserjs


#include "host_function_darwin.h"

fn C.vox_install_js_host_function(context voidptr, name &char, record voidptr) bool
fn C.JSObjectGetPrivate(object voidptr) voidptr
fn C.vox_jsc_JSValueMakeString(context voidptr, string_value voidptr) voidptr
fn C.vox_jsc_JSValueMakeUndefined(context voidptr) voidptr
fn C.vox_jsc_JSObjectMakeError(context voidptr, count uint, arguments &voidptr, exception &voidptr) voidptr

fn host_function_error(context voidptr, message string, exception &voidptr) voidptr {
	string_value := js_source_string(message)
	value := C.vox_jsc_JSValueMakeString(context, string_value)
	C.JSStringRelease(string_value)
	mut ignored := unsafe { nil }
	object := C.vox_jsc_JSObjectMakeError(context, 1, &value, &ignored)
	unsafe { *exception = object }
	if ignored != unsafe { nil } { unsafe { *exception = ignored } }
	return C.vox_jsc_JSValueMakeUndefined(context)
}

@[export: 'vox_jsc_host_function']
fn javascript_core_host_function(context voidptr, function voidptr, _ voidptr, count uint, arguments &voidptr, exception &voidptr) voidptr {
	record := unsafe { &HostFunctionRecord(C.JSObjectGetPrivate(function)) }
	mut argument := C.vox_jsc_JSValueMakeUndefined(context)
	if count > 0 { argument = unsafe { arguments[0] } }
	input := js_string_to_v(context, argument) or { return host_function_error(context, err.msg(), exception) }
	output := record.callback(input) or { return host_function_error(context, err.msg(), exception) }
	string_value := js_source_string(output)
	defer { C.JSStringRelease(string_value) }
	return C.vox_jsc_JSValueMakeString(context, string_value)
}

fn install_javascript_core_host_function(context voidptr, name string, record &HostFunctionRecord) ! {
	if context == unsafe { nil } { return error('JavaScriptCore context creation failed') }
	if !C.vox_install_js_host_function(context, name.str, record) {
		return error('JavaScriptCore host function installation failed')
	}
}
