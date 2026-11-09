// Window.cpp:1617 and source generated Replaceable getter/setter steps.
@[has_globals]
module browserjs

import html


__global window_current_event_bindings_ = map[voidptr]bool{}

pub fn (mut runtime Runtime) install_window_current_event_binding() ! {
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if window_current_event_bindings_[owner] { return }
	runtime.install_window_event_handler_binding()!
	runtime.define_value_host_function('__ladybirdWindowCurrentEvent', fn [owner] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		if args.len < 2 {
			return runtime.event_binding_type_error('Missing internal Window.event arguments')
		}
		target := runtime.native_event_target(args[1])!
		if target.data.kind != .window {
			return runtime.event_binding_type_error('Window.event receiver is not a Window')
		}
		mut window := ?&html.WindowModel(none)
		for candidate in html.all_windows() {
			if voidptr(candidate) == voidptr(target) {
				window = candidate
				break
			}
		}
		actual_window := window or { return error('Window.event requires its actual owning Window model') }
		method := runtime.binding_dom_string(args[0])!
		if method == 'validate' { return C.vox_jsc_JSValueMakeUndefined(runtime.context) }
		if method != 'get' {
			return runtime.event_binding_type_error('Unknown Window.event operation')
		}
		if current := actual_window.event() { return runtime.javascript_event(current)! }
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	})!
	factory := runtime.evaluate_host_value(window_current_event_binding_factory())!
	global := C.JSContextGetGlobalObject(runtime.context)
	runtime.call_javascript_function(factory, global, [global])!
	register_runtime_binding(mut window_current_event_bindings_, owner, true)
	runtime.add_close_handler(fn [owner] () { unregister_runtime_binding(mut window_current_event_bindings_, owner) })
}
