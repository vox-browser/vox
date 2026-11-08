// SPDX-License-Identifier: BSD-2-Clause
module browserjs

// Carry the genuine FileList wrapper through the private compact DOM transport.
// JSON cannot preserve its native implementation identity.
pub fn (mut runtime Runtime) install_input_files_binding(operate fn (string, string, bool, voidptr) !voidptr) ! {
	owner := voidptr(&runtime)
	function := runtime.make_value_host_function(fn [owner, operate] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		if args.len != 4 { return error('TypeError: Invalid input files operation') }
		key := runtime.binding_dom_string(args[0])!
		state := runtime.binding_dom_string(args[1])!
		write := C.JSValueToBoolean(runtime.context, args[2])
		return operate(key, state, write, args[3]) or {
			return runtime.actual_javascript_exception(runtime.binding_exception_value(err))
		}
	})!
	name := C.JSStringCreateWithUTF8CString(c'__ladybirdInputFiles')
	defer { C.JSStringRelease(name) }
	mut exception := unsafe { nil }
	C.vox_jsc_JSObjectSetProperty(runtime.context, C.JSContextGetGlobalObject(runtime.context), name, function, 0, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
}
