// WebIDL/ExceptionOrUtils.h: SimpleException -> actual engine thrown Error.
@[has_globals]
module browserjs

import webidl


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
		runtime.add_close_handler(fn [owner] () { unregister_runtime_binding(mut simple_exception_bindings_, owner) })
		new_binding
	}
	if wrapper := binding.wrappers[voidptr(native)] { return wrapper.object }
	object := runtime.call_engine_function(runtime.value_error_intrinsic_, [runtime.binding_string(native.name()), runtime.binding_string(native.message)])!
	runtime.retain_javascript_value(object)!
	binding.wrappers[voidptr(native)] = &SimpleExceptionJavaScriptWrapper{native: native, object: object}
	return object
}
