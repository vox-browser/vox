module browserjs

import webidl
import dom


// Resolve the native operation's capability, preserving real realm Promises
// and the original JavaScript rejection value across the compact query bridge.
pub fn (mut runtime Runtime) install_scroll_promise_binding(resolve ScrollPromiseResolver) ! {
	owner_handle := voidptr(&runtime)
	runtime.define_value_host_function('__ladybirdScrollPromise', fn [owner_handle, resolve] (_ voidptr, args []voidptr) !voidptr {
		mut owner := unsafe { &Runtime(owner_handle) }
		settings := owner.scripting_settings_ or { return error('Scroll Promise requires its actual settings owner') }
		context := settings.stream_promise_context()
		mut native := &webidl.Promise(unsafe { nil })
		mut operation := ?&dom.Promise(none)
		if args.len > 1 {
			native = webidl.create_rejected_promise_for(context, owner.webidl_value(args[1])!)
		} else {
			if args.len == 0 { return error('Missing native scroll operation') }
			key := owner.binding_dom_string(args[0])!
			resolved_operation := resolve(key) or { return error('Unknown native scroll operation') }
			operation = resolved_operation
			if capability := resolved_operation.webidl_promise() {
				native = capability
			} else {
				// Inactive/no-box source algorithms return an already fulfilled
				// legacy DOM Promise, with no pending operation to observe.
				if resolved_operation.state() != .fulfilled { return error('Scroll operation has no native capability') }
				native = webidl.create_resolved_promise_for(context, webidl.undefined_value())
			}
		}
		return owner.javascript_webidl_promise_with_converters(native, fn [owner_handle, operation] (value webidl.Value) !voidptr {
			mut owner := unsafe { &Runtime(owner_handle) }
			if value.kind != .undefined { return error('Invalid native scroll fulfillment') }
			interrupted := if source := operation { source.scroll_interrupted_ } else { false }
			object := C.JSObjectMake(owner.context, unsafe { nil }, unsafe { nil })
			key := C.JSStringCreateWithUTF8CString(c'interrupted')
			defer { C.JSStringRelease(key) }
			mut exception := voidptr(0)
			C.vox_jsc_JSObjectSetProperty(owner.context, object, key, C.vox_jsc_JSValueMakeBoolean(owner.context, interrupted), 0, &exception)
			if exception != unsafe { nil } { return owner.actual_javascript_exception(exception) }
			return object
		}, fn [owner_handle] (value webidl.Value) !voidptr {
			mut owner := unsafe { &Runtime(owner_handle) }
			if value.kind == .runtime_value { return owner.actual_webidl_value(value) }
			if value.kind == .undefined { return C.vox_jsc_JSValueMakeUndefined(owner.context) }
			if _ := value.dom_exception_ { return owner.javascript_dom_exception(value) }
			return error('Value is outside the scroll Promise binding')
		})
	})!
}
