module browserjs

fn (mut runtime Runtime) install_window_open_binding() ! {
	owner := voidptr(&runtime)
	operation := runtime.make_native_value_host_function('open',0,fn [owner] (receiver voidptr, arguments []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		mut window := runtime.message_window(receiver)!
		mut values := []string{}
		for index, fallback in ['', '_blank', ''] {
			values << if index >= arguments.len || C.JSValueIsUndefined(runtime.context,arguments[index]) { fallback } else { runtime.binding_dom_string(arguments[index])! }
		}
		result := window.window_open_steps(values[0],values[1],values[2])!
		if proxy := result.window_proxy { return runtime.javascript_window_proxy(proxy.dom_proxy()) }
		return C.vox_jsc_JSValueMakeNull(runtime.context)
	})!
	installer := runtime.evaluate_host_value(r'(function(open){Object.defineProperty(globalThis,"open",{value:open,writable:true,enumerable:true,configurable:true})})')!
	defer { runtime.release_javascript_value(installer) }
	runtime.call_javascript_function(installer,C.JSContextGetGlobalObject(runtime.context),[operation])!
}
