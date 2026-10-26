@[has_globals]
module browserjs

import geometry
import platform
import webidl

@[heap]
struct DOMRectReadOnlyBinding {
mut:
	make     voidptr
	rects    map[voidptr]&geometry.DOMRectReadOnly
	wrappers map[voidptr]voidptr
}

__global dom_rect_read_only_bindings_ = map[voidptr]&DOMRectReadOnlyBinding{}

pub fn (mut runtime Runtime) install_dom_rect_read_only_binding() ! {
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if owner in dom_rect_read_only_bindings_ { return }
	mut binding := &DOMRectReadOnlyBinding{}
	operation := runtime.make_value_host_function(fn [owner, mut binding] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		mut allocation_scope := platform.RetainedArenaScope{}
		if settings := runtime.scripting_settings_ {
			if document := settings.responsible_document() {
				mut storage := document.native_storage()
				if storage != unsafe { nil } { allocation_scope = storage.enter_nested() }
			}
		}
		defer { allocation_scope.finish() }
		return runtime.dom_rect_read_only_operation(mut binding, args) or {
			if err is JavaScriptValueException { return err }
			return runtime.actual_javascript_exception(runtime.binding_exception_value(err))
		}
	})!
	factory := runtime.evaluate_host_value(dom_rect_read_only_binding_factory())!
	defer { runtime.release_javascript_value(factory) }
	global := C.JSContextGetGlobalObject(runtime.context)
	binding.make = runtime.retain_javascript_value(runtime.call_javascript_function(factory, global, [
		operation,
		global,
	])!)!
	dom_rect_read_only_bindings_[owner] = binding
	runtime.add_close_handler(fn [owner, mut binding] () {
		binding.rects = {}
		binding.wrappers = {}
		dom_rect_read_only_bindings_.delete(owner)
	})
}

fn (mut runtime Runtime) javascript_read_only_rect(rect &geometry.DOMRectReadOnly) !voidptr {
	mut binding := dom_rect_read_only_bindings_[voidptr(&runtime)] or { return error('DOMRectReadOnly binding is missing') }
	if wrapper := binding.wrappers[voidptr(rect)] { return wrapper }
	wrapper := runtime.retain_javascript_value(runtime.call_javascript_function(binding.make, C.JSValueMakeUndefined(runtime.context), [])!)!
	binding.rects[wrapper] = rect
	binding.wrappers[voidptr(rect)] = wrapper
	return wrapper
}

fn (mut runtime Runtime) dom_rect_read_only_operation(mut binding DOMRectReadOnlyBinding, args []voidptr) !voidptr {
	if args.len < 2 { return runtime.event_binding_type_error('Missing DOMRectReadOnly operation') }
	method := runtime.binding_dom_string(args[0])!
	receiver := args[1]
	if method == 'number' {
		return C.JSValueMakeNumber(runtime.context, webidl.value_to_number(runtime.webidl_value(args[2])!)!)
	}
	if method == 'construct' {
		mut values := []f64{cap: 4}
		for value in args[2..6] { values << webidl.value_to_number(runtime.webidl_value(value)!)! }
		rect := geometry.DOMRectReadOnly.construct(values[0], values[1], values[2], values[3])
		runtime.retain_javascript_value(receiver)!
		binding.rects[receiver] = rect
		binding.wrappers[voidptr(rect)] = receiver
		return C.JSValueMakeUndefined(runtime.context)
	}
	rect := binding.rects[receiver] or { return runtime.event_binding_type_error('Illegal DOMRectReadOnly receiver') }
	if method == 'brand' { return C.JSValueMakeUndefined(runtime.context) }
	value := match method {
		'x' { rect.x() }
		'y' { rect.y() }
		'width' { rect.width() }
		'height' { rect.height() }
		'top' { rect.top() }
		'right' { rect.right() }
		'bottom' { rect.bottom() }
		'left' { rect.left() }
		else { return error('Unknown DOMRectReadOnly operation') }
	}
	return C.JSValueMakeNumber(runtime.context, value)
}
