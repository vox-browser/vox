@[has_globals]
module browserjs

import dom
import html
import platform
import strconv
import webidl

@[heap]
struct WindowProxyBinding {
	frame FrameWindowResolver
mut:
	factory    voidptr
	by_wrapper map[voidptr]&dom.WindowProxy
	by_native  map[voidptr]voidptr
}

__global window_proxy_bindings_ = map[voidptr]&WindowProxyBinding{}

pub fn (mut runtime Runtime) install_window_proxy_binding(frame FrameWindowResolver) ! {
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if owner in window_proxy_bindings_ { return }
	runtime.install_window_self_binding()!
	runtime.install_window_message_binding()!
	runtime.own_closure(voidptr(frame))
	mut binding := &WindowProxyBinding{ frame: frame }
	operation := runtime.make_value_host_function(fn [owner, binding] (_ voidptr, args []voidptr) !voidptr {
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut runtime := unsafe { &Runtime(owner) }
		return runtime.window_proxy_operation(binding, args) or {
			return runtime.actual_javascript_exception(runtime.binding_exception_value(err))
		}
	})!
	factory := runtime.evaluate_host_value(window_proxy_binding_factory())!
	defer { runtime.release_javascript_value(factory) }
	global := C.JSContextGetGlobalObject(runtime.context)
	binding.factory = runtime.retain_javascript_value(runtime.call_javascript_function(factory, global, [
		operation,
		global,
	])!)!
	register_runtime_binding(mut window_proxy_bindings_, owner, binding)
	runtime.install_window_open_binding()!
	runtime.add_close_handler(fn [owner, mut binding] () {
		binding.by_wrapper = {}
		binding.by_native = {}
		unregister_runtime_binding(mut window_proxy_bindings_, owner)
	})
}

fn (runtime &Runtime) native_window_proxy(wrapper voidptr) ?&dom.WindowProxy {
	binding := window_proxy_bindings_[voidptr(runtime)] or { return none }
	return binding.by_wrapper[wrapper] or { return none }
}

fn window_model_for_proxy(proxy &dom.WindowProxy) !&html.WindowModel {
	window := proxy.window() or { return error('InvalidStateError: WindowProxy has no Window') }
	for candidate in html.all_windows() {
		if voidptr(candidate) == voidptr(window) { return candidate }
	}
	return error('InvalidStateError: WindowProxy has no HTML owner')
}

// Every Window realm on this thread shares the agent's JSC context group, so
// a same-origin-domain WindowProxy can expose the other realm's global object
// itself: its document, functions and globals then behave as one agent.
fn (runtime &Runtime) same_agent_window_global(window &html.WindowModel) ?voidptr {
	settings := runtime.scripting_settings_ or { return none }
	if !window.associated_document().origin().is_same_origin_domain(settings.origin()) { return none }
	group := C.JSContextGetGroup(runtime.context)
	for owner, _ in window_proxy_bindings_ {
		if owner == voidptr(runtime) { continue }
		other := unsafe { &Runtime(owner) }
		if other.closed || other.context == unsafe { nil } { continue }
		other_settings := other.scripting_settings_ or { continue }
		if voidptr(other_settings.global_object()) != voidptr(window) { continue }
		if C.JSContextGetGroup(other.context) != group { return none }
		return C.JSContextGetGlobalObject(other.context)
	}
	return none
}

// The global of a same-origin frame's realm. A WindowProxy handed out before
// its frame had a realm creates the initial one through the frame's container.
fn (mut runtime Runtime) window_proxy_realm_global(binding &WindowProxyBinding, window &html.WindowModel) ?voidptr {
	if global := runtime.same_agent_window_global(window) { return global }
	wrapper := runtime.window_container_wrapper(window) or { return none }
	binding.frame(wrapper, true) or { return none }
	return runtime.same_agent_window_global(window)
}

fn (mut runtime Runtime) window_container_wrapper(window &html.WindowModel) ?voidptr {
	navigable := window.associated_document().navigable() or { return none }
	container := navigable.container() or { return none }
	return runtime.javascript_event_target(unsafe { &dom.EventTarget(container) }, none) or { return none }
}

fn (mut runtime Runtime) javascript_window_proxy(proxy &dom.WindowProxy) !voidptr {
	window := window_model_for_proxy(proxy)!
	if settings := runtime.scripting_settings_ {
		if voidptr(settings.global_object()) == voidptr(window) {
			return C.JSContextGetGlobalObject(runtime.context)
		}
	}
	if global := runtime.same_agent_window_global(window) { return global }
	mut binding := window_proxy_bindings_[voidptr(runtime)] or {
		return runtime.javascript_event_target(unsafe { &dom.EventTarget(window) }, none)
	}
	// The initial about:blank Window already has a realm when contentWindow
	// is exposed. Returning a placeholder until its first property read changes
	// identity on the next read and wraps native functions such as eval.
	document := window.associated_document()
	if document.get_is_initial_about_blank() && !document.has_been_destroyed() {
		if global := runtime.window_proxy_realm_global(binding, window) { return global }
	}
	if wrapper := binding.by_native[voidptr(proxy)] { return wrapper }
	wrapper := runtime.call_javascript_function(binding.factory, C.vox_jsc_JSValueMakeUndefined(runtime.context), [])!
	binding.by_wrapper[wrapper] = proxy
	binding.by_native[voidptr(proxy)] = runtime.retain_javascript_value(wrapper)!
	return wrapper
}

fn (mut runtime Runtime) window_proxy_security_error() !voidptr {
	value := webidl.dom_exception_value(webidl.DOMException.create('SecurityError', 'Blocked cross-origin Window access'))
	return runtime.actual_javascript_exception(runtime.javascript_dom_exception(value)!)
}

fn (mut runtime Runtime) window_proxy_operation(binding &WindowProxyBinding, args []voidptr) !voidptr {
	if args.len < 2 { return runtime.event_binding_type_error('Missing Window operation') }
	method := runtime.binding_dom_string(args[0])!
	if method == 'frame' || method == 'frameRealm' {
		result := binding.frame(args[1], method == 'frameRealm')!
		if proxy := result.proxy { return runtime.javascript_window_proxy(proxy) }
		return C.vox_jsc_JSValueMakeNull(runtime.context)
	}
	proxy := if value := runtime.native_window_proxy(args[1]) {
		value
	} else {
		window := runtime.message_window(args[1])!
		window.window().dom_proxy()
	}
	mut window := window_model_for_proxy(proxy)!
	settings := runtime.scripting_settings_ or { return error('Window access requires its owning settings') }
	same_origin := window.associated_document().origin().is_same_origin_domain(settings.origin())
	match method {
		'brand' { return C.vox_jsc_JSValueMakeUndefined(runtime.context) }
		'sameOrigin' { return C.vox_jsc_JSValueMakeBoolean(runtime.context, same_origin) }
		'parent' {
			parent := window.parent() or { return C.vox_jsc_JSValueMakeNull(runtime.context) }
			return runtime.javascript_window_proxy(parent.dom_proxy())
		}
		'top' {
			top := window.top() or { return C.vox_jsc_JSValueMakeNull(runtime.context) }
			return runtime.javascript_window_proxy(top.dom_proxy())
		}
		'opener' {
			if opener := window.opener() {
				return runtime.javascript_window_proxy(opener.dom_proxy())
			}
			return C.vox_jsc_JSValueMakeNull(runtime.context)
		}
		'closed' { return C.vox_jsc_JSValueMakeBoolean(runtime.context, window.closed()) }
		'length' { return C.vox_jsc_JSValueMakeNumber(runtime.context, window.length()) }
		'index' {
			index := strconv.atoi(runtime.binding_dom_string(args[2])!) or { return C.vox_jsc_JSValueMakeUndefined(runtime.context) }
			children := window.associated_document().document_tree_child_navigables()
			if index >= 0 && index < children.len {
				if child := children[index].active_window_proxy() {
					return runtime.javascript_window_proxy(child)
				}
			}
			return C.vox_jsc_JSValueMakeUndefined(runtime.context)
		}
		'close' { window.close() }
		'focus' { window.focus() }
		'blur' { window.blur() }
		'get' {
			if !same_origin { return runtime.window_proxy_security_error() }
			if args.len < 3 { return C.vox_jsc_JSValueMakeUndefined(runtime.context) }
			if value := runtime.window_proxy_realm_global(binding, window) {
				return runtime.binding_property(value, runtime.binding_dom_string(args[2])!)
			}
			return C.vox_jsc_JSValueMakeUndefined(runtime.context)
		}
		'realmGlobal' {
			if !same_origin { return runtime.window_proxy_security_error() }
			return runtime.window_proxy_realm_global(binding, window) or { C.vox_jsc_JSValueMakeUndefined(runtime.context) }
		}
		'set' {
			if !same_origin || args.len < 4 { return runtime.window_proxy_security_error() }
			global := runtime.window_proxy_realm_global(binding, window) or {
				return runtime.window_proxy_security_error()
			}
			name := js_source_string(runtime.binding_dom_string(args[2])!)
			defer { C.JSStringRelease(name) }
			mut exception := unsafe { nil }
			C.vox_jsc_JSObjectSetProperty(runtime.context, global, name, args[3], 0, &exception)
			if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
			return C.vox_jsc_JSValueMakeBoolean(runtime.context, true)
		}
		'write' { return runtime.window_proxy_security_error() }
		else { return error('Unknown Window operation') }
	}
	return C.vox_jsc_JSValueMakeUndefined(runtime.context)
}
