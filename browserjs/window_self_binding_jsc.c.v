@[has_globals]
module browserjs

import dom
import html

__global window_self_bindings_ = map[voidptr]bool{}

pub fn (mut runtime Runtime) install_window_self_binding() ! {
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if window_self_bindings_[owner] { return }
	runtime.install_window_event_handler_binding()!
	runtime.define_value_host_function('__ladybirdWindowSelf', fn [owner] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		if args.len == 0 { return runtime.event_binding_type_error('Missing Window.self receiver') }
		target := runtime.native_event_target(args[0])!
		if target.data.kind != .window {
			return runtime.event_binding_type_error('Window.self receiver is not a Window')
		}
		for window in html.all_windows() {
			if voidptr(window) == voidptr(target) {
				return runtime.javascript_event_target(unsafe { &dom.EventTarget(window.self().window()) }, none)
			}
		}
		return error('Window.self requires its actual owning Window model')
	})!
	factory := runtime.evaluate_host_value(window_self_binding_factory())!
	defer { runtime.release_javascript_value(factory) }
	global := C.JSContextGetGlobalObject(runtime.context)
	runtime.call_javascript_function(factory, global, [global])!
	window_self_bindings_[owner] = true
	runtime.add_close_handler(fn [owner] () { window_self_bindings_.delete(owner) })
}
