// Window.idl optional DOMString conversion, then Window.cpp:2344-2365.
@[has_globals]
module browserjs

import html


__global window_find_bindings_ = map[voidptr]bool{}

pub fn (mut runtime Runtime) install_window_find_binding(before_search ?WindowFindBeforeSearchHook) ! {
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if window_find_bindings_[owner] { return }
	runtime.install_window_event_handler_binding()!
	runtime.define_value_host_function('__ladybirdWindowFind', fn [owner, before_search] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		if args.len < 2 {
			return runtime.event_binding_type_error('Missing internal Window.find arguments')
		}
		target := runtime.native_event_target(args[0])!
		if target.data.kind != .window {
			return runtime.event_binding_type_error('Window.find receiver is not a Window')
		}
		mut window := ?&html.WindowModel(none)
		for candidate in html.all_windows() {
			if voidptr(candidate) == voidptr(target) {
				window = candidate
				break
			}
		}
		mut actual_window := window or { return error('Window.find requires its actual owning Window model') }
		// Receiver validation precedes argument conversion. Missing/undefined
		// use the IDL default; other values use DOMString, and extra args are ignored.
		query := if C.JSValueIsUndefined(runtime.context, args[1]) {
			''
		} else {
			runtime.binding_dom_string(args[1])!
		}
		// Compact facade writes (including coercion side effects) must reach the
		// actual DOM before the existing source rendered-search algorithm runs.
		if synchronize := before_search { synchronize(runtime)! }
		result := actual_window.find(query)
		runtime.mark_document_state_dirty()
		return C.vox_jsc_JSValueMakeBoolean(runtime.context, result)
	})!
	factory := runtime.evaluate_host_value(window_find_binding_factory())!
	global := C.JSContextGetGlobalObject(runtime.context)
	runtime.call_javascript_function(factory, global, [global])!
	register_runtime_binding(mut window_find_bindings_, owner, true)
	runtime.add_close_handler(fn [owner] () { unregister_runtime_binding(mut window_find_bindings_, owner) })
}
