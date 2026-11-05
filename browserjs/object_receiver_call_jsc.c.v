// Object receivers already have the representation accepted by JSC's direct
// call API. Primitive receivers still need the captured Reflect.apply helper:
// a null native thisObject means the global object, including for strict code.
@[has_globals]
module browserjs

import os

const disable_object_receiver_call = os.getenv('VOX_DISABLE_OBJECT_RECEIVER_CALL') != ''
const object_receiver_call_diagnostics = os.getenv('VOX_OBJECT_RECEIVER_CALL_DIAGNOSTICS') != ''

__global object_receiver_call_reported bool

fn (runtime &Runtime) can_call_with_object_receiver(function voidptr, receiver voidptr) bool {
	return !disable_object_receiver_call && receiver != unsafe { nil }
		&& function != unsafe { nil } && C.JSValueIsObject(runtime.context, receiver)
		&& C.JSValueIsObject(runtime.context, function)
		&& C.JSObjectIsFunction(runtime.context, function)
}

fn (runtime &Runtime) call_with_object_receiver(function voidptr, receiver voidptr,
	arguments []voidptr) !voidptr {
	// Keep the owning HTML realm active through the engine's Promise drain,
	// just as call_engine_function does for the captured intrinsic.
	runtime.prepare_html_script()
	defer { runtime.clean_up_html_script() }
	mut exception := unsafe { nil }
	value := C.vox_jsc_JSObjectCallAsFunction(runtime.context, function, receiver,
		uint(arguments.len), arguments.data, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	if object_receiver_call_diagnostics && !object_receiver_call_reported {
		object_receiver_call_reported = true
		eprintln('Vox object callback: called JavaScriptCore with an object receiver')
	}
	return value
}
