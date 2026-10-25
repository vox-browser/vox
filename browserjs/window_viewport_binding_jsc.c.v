@[has_globals]
module browserjs

import html

__global window_viewport_bindings_ = map[voidptr]bool{}

pub fn (mut runtime Runtime) install_window_viewport_binding() ! {
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if window_viewport_bindings_[owner] { return }
	runtime.install_window_event_handler_binding()!
	read := runtime.make_value_host_function(fn [owner] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		if args.len < 2 {
			return runtime.event_binding_type_error('Missing Window viewport receiver')
		}
		target := runtime.native_event_target(args[0])!
		if target.data.kind != .window {
			return runtime.event_binding_type_error('Viewport receiver is not a Window')
		}
		name := runtime.binding_dom_string(args[1])!
		for window in html.all_windows() {
			if voidptr(window) != voidptr(target) { continue }
			value := match name {
				'innerWidth' { f64(window.inner_width()) }
				'innerHeight' { f64(window.inner_height()) }
				'devicePixelRatio' { window.device_pixel_ratio() }
				else { return error('Unknown Window viewport attribute') }
			}
			return C.JSValueMakeNumber(runtime.context, value)
		}
		return error('Viewport attributes require their actual owning Window model')
	})!
	factory := runtime.evaluate_host_value(window_viewport_binding_factory())!
	defer { runtime.release_javascript_value(factory) }
	global := C.JSContextGetGlobalObject(runtime.context)
	runtime.call_javascript_function(factory, global, [read, global])!
	window_viewport_bindings_[owner] = true
	runtime.add_close_handler(fn [owner] () { window_viewport_bindings_.delete(owner) })
}
