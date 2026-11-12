// WebIDL/ExceptionOrUtils.h: SimpleException -> actual engine thrown Error.
@[has_globals]
module browserjs

import webidl

#include "native_error.h"

fn C.vox_jsc_construct_error(context voidptr, constructor voidptr, message voidptr, exception &voidptr) voidptr

// Construct through the captured engine constructor. A JavaScript factory
// adds its own frame to every platform error's author-visible stack.
fn (runtime &Runtime) make_engine_error(kind string, message voidptr) !voidptr {
	name := if kind in ['TypeError', 'RangeError', 'EvalError', 'ReferenceError', 'URIError'] {
		kind
	} else {
		'Error'
	}
	constructor := runtime.binding_property(runtime.value_error_constructors_, name)!
	mut exception := unsafe { nil }
	object := C.vox_jsc_construct_error(runtime.context, constructor, message, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	return object
}

@[heap]
struct SimpleExceptionJavaScriptWrapper {
	native &webidl.SimpleException
	object voidptr
}

@[heap]
struct SimpleExceptionBinding {
mut:
	wrappers map[voidptr]&SimpleExceptionJavaScriptWrapper
}

__global simple_exception_bindings_ = map[voidptr]&SimpleExceptionBinding{}

pub fn (mut runtime Runtime) javascript_simple_exception(value webidl.Value) !voidptr {
	runtime.require_javascript_value_context()!
	native := value.simple_exception_ or { return error('SimpleException value has no native descriptor') }
	owner := voidptr(&runtime)
	mut binding := simple_exception_bindings_[owner] or {
		new_binding := &SimpleExceptionBinding{}
		register_runtime_binding(mut simple_exception_bindings_, owner, new_binding)
		runtime.add_close_handler(fn [owner] () {
			unregister_runtime_binding(mut simple_exception_bindings_, owner)
		})
		new_binding
	}
	if wrapper := binding.wrappers[voidptr(native)] { return wrapper.object }
	object := runtime.make_engine_error(native.name(), runtime.binding_string(native.message))!
	runtime.retain_javascript_value(object)!
	binding.wrappers[voidptr(native)] = &SimpleExceptionJavaScriptWrapper{ native: native, object: object }
	return object
}
