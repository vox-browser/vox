// WebIDL/DOMException.idl wrappers retain the actual native record and engine object.
@[has_globals]
module browserjs

import webidl

fn C.JSValueIsUndefined(context voidptr, value voidptr) bool
fn C.JSValueIsNull(context voidptr, value voidptr) bool
fn C.JSValueMakeNumber(context voidptr, value f64) voidptr

@[heap]
struct DOMExceptionBinding {
mut:
	by_wrapper map[voidptr]&webidl.DOMException
	by_record  map[voidptr]voidptr
	factory    voidptr
}

__global dom_exception_bindings_ = map[voidptr]&DOMExceptionBinding{}

fn (runtime &Runtime) binding_dom_string(value voidptr) !string {
	mut exception := unsafe { nil }
	text := C.JSValueToStringCopy(runtime.context, value, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	if text == unsafe { nil } { return error('Failed to convert IDL string') }
	defer { C.JSStringRelease(text) }
	mut bytes := []u8{len: int(C.JSStringGetMaximumUTF8CStringSize(text))}
	length := unsafe { C.JSStringGetUTF8CString(text, &char(bytes.data), usize(bytes.len)) }
	if length == 0 { return error('Failed to convert IDL string') }
	return bytes[..int(length) - 1].bytestr()
}

fn (runtime &Runtime) binding_string(value string) voidptr {
	text := js_source_string(value)
	defer { C.JSStringRelease(text) }
	return C.JSValueMakeString(runtime.context, text)
}

fn (runtime &Runtime) binding_property(object voidptr, name string) !voidptr {
	text := js_source_string(name)
	defer { C.JSStringRelease(text) }
	mut exception := unsafe { nil }
	value := C.JSObjectGetProperty(runtime.context, object, text, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	return value
}

pub fn (mut runtime Runtime) install_dom_exception_binding() ! {
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if _ := dom_exception_bindings_[owner] { return }
	mut binding := &DOMExceptionBinding{}
	dom_exception_bindings_[owner] = binding
	runtime.define_value_host_function('__ladybirdDOMExceptionConstruct', fn [owner, mut binding] (receiver voidptr, args []voidptr) !voidptr {
		runtime := unsafe { &Runtime(owner) }
		message := if args.len > 0 && !C.JSValueIsUndefined(runtime.context, args[0]) {
			runtime.binding_dom_string(args[0])!
		} else {
			''
		}
		name := if args.len > 1 && !C.JSValueIsUndefined(runtime.context, args[1]) {
			runtime.binding_dom_string(args[1])!
		} else {
			'Error'
		}
		exception := webidl.DOMException.create_record(name, message)
		binding.by_wrapper[receiver] = exception
		binding.by_record[voidptr(exception)] = receiver
		mut mutable_runtime := unsafe { &Runtime(owner) }
		mutable_runtime.retain_javascript_value(receiver)!
		return C.JSValueMakeUndefined(runtime.context)
	})!
	runtime.define_value_host_function('__ladybirdDOMExceptionGet', fn [owner, binding] (receiver voidptr, args []voidptr) !voidptr {
		runtime := unsafe { &Runtime(owner) }
		exception := binding.by_wrapper[receiver] or {
			return runtime.actual_javascript_exception(runtime.binding_exception_value(error('TypeError: Illegal DOMException receiver')))
		}
		name := runtime.binding_dom_string(args[0])!
		return match name {
			'name' { runtime.binding_string(exception.name()) }
			'message' { runtime.binding_string(exception.message()) }
			'code' { C.JSValueMakeNumber(runtime.context, exception.code()) }
			else { return error('TypeError: Unknown DOMException attribute') }
		}
	})!
	runtime.add_close_handler(fn [owner] () {
		dom_exception_bindings_.delete(owner)
	})
	runtime.evaluate_host(dom_exception_bootstrap())!
	binding.factory =
		runtime.evaluate_host_value('(function(){const create=Object.create,prototype=DOMException.prototype;return function(){return create(prototype)}})()')!
}

pub fn (mut runtime Runtime) javascript_dom_exception(value webidl.Value) !voidptr {
	runtime.install_dom_exception_binding()!
	native := value.dom_exception_ or { return error('DOMException value has no native record') }
	mut binding := dom_exception_bindings_[voidptr(&runtime)] or {
		return error('DOMException binding unavailable')
	}
	if actual := binding.by_record[voidptr(native)] { return actual }
	object := runtime.call_javascript_function(binding.factory,
		C.JSValueMakeUndefined(runtime.context), [])!
	runtime.retain_javascript_value(object)!
	binding.by_wrapper[object] = native
	binding.by_record[voidptr(native)] = object
	return object
}

pub fn (runtime &Runtime) native_dom_exception(value voidptr) !webidl.Value {
	binding := dom_exception_bindings_[voidptr(runtime)] or {
		return error('DOMException binding unavailable')
	}
	native := binding.by_wrapper[value] or {
		return error('TypeError: Value is not a DOMException')
	}
	return webidl.dom_exception_value_for_record(native)
}
