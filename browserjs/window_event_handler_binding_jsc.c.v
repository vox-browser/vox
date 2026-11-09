// Actual Window identity and Source EventHandler attribute operations.
@[has_globals]
module browserjs


__global window_event_handler_bindings_ = map[voidptr]bool{}

pub fn (mut runtime Runtime) install_window_event_handler_binding() ! {
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if window_event_handler_bindings_[owner] { return }
	settings := runtime.scripting_settings_ or { return error('Window handlers require their actual owning settings') }
	target := settings.global_object()
	if target.data.kind != .window {
		return error('Window handlers require an actual Window global')
	}
	runtime.install_event_target_binding()!
	// Register the actual engine global instead of manufacturing a second Window
	// object. Existing Source callback/Event maps then preserve `this` identity.
	global := C.JSContextGetGlobalObject(runtime.context)
	runtime.bind_event_target(global, target)!
	runtime.define_value_host_function('__ladybirdWindowHandler', fn [owner] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		if args.len < 3 {
			return runtime.event_binding_type_error('Missing internal Window handler arguments')
		}
		method := runtime.binding_dom_string(args[0])!
		target := runtime.native_event_target(args[1])!
		if target.data.kind != .window {
			return runtime.event_binding_type_error('Window handler receiver is not a Window')
		}
		name := runtime.binding_dom_string(args[2])!
		if !is_window_event_handler_name(name) {
			return runtime.event_binding_type_error('Unknown Window event handler')
		}
		if method == 'get' { return runtime.javascript_event_handler(target, name) }
		if method == 'set' && args.len >= 4 {
			runtime.set_javascript_event_handler(target, name, args[3])!
			return C.vox_jsc_JSValueMakeUndefined(runtime.context)
		}
		return runtime.event_binding_type_error('Unknown Window handler operation')
	})!
	factory := runtime.evaluate_host_value(window_event_handler_bootstrap())!
	runtime.call_javascript_function(factory, global, [global])!
	register_runtime_binding(mut window_event_handler_bindings_, owner, true)
	runtime.add_close_handler(fn [owner] () { unregister_runtime_binding(mut window_event_handler_bindings_, owner) })
}
