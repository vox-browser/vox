@[has_globals]
module browserjs

import dom
import html
import platform
import webidl

@[heap]
struct MessageChannelBinding {
	clone &StructuredCloneBridge
	transfer &ArrayBufferTransferBridge
mut:
	prototype voidptr
	channels  map[voidptr]&html.MessageChannel
	ports     map[voidptr]&html.MessagePort
}

__global message_channel_bindings_ = map[voidptr]&MessageChannelBinding{}

pub fn (mut runtime Runtime) install_message_channel_binding() ! {
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if owner in message_channel_bindings_ { return }
	runtime.install_message_event_binding()!
	transfer := ArrayBufferTransferBridge.create(&runtime)!
	mut binding := &MessageChannelBinding{ clone: transfer.clone, transfer: transfer }
	operation := runtime.make_value_host_function(fn [owner, mut binding] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		// Wrappers and the native port registry outlive individual script calls.
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		return runtime.message_channel_operation(mut binding, args) or {
			if err is JavaScriptValueException { return err }
			value := webidl.exception_value(err)
			if value.dom_exception_ != none {
				return runtime.actual_javascript_exception(runtime.javascript_dom_exception(value)!)
			}
			return runtime.actual_javascript_exception(runtime.binding_exception_value(err))
		}
	})!
	factory := runtime.evaluate_host_value(message_channel_binding_factory())!
	defer { runtime.release_javascript_value(factory) }
	global := C.JSContextGetGlobalObject(runtime.context)
	binding.prototype = runtime.retain_javascript_value(runtime.call_javascript_function(factory, global, [
		operation,
		global,
	])!)!
	register_runtime_binding(mut message_channel_bindings_, owner, binding)
	runtime.add_close_handler(fn [owner, mut binding] () {
		// Already scheduled posted-message tasks must not enter a closed realm.
		for _, pointer in binding.ports {
			mut port := unsafe { &html.MessagePort(pointer) }
			port.discard_pending_messages()
			port.close()
		}
		binding.ports = {}
		binding.channels = {}
		unregister_runtime_binding(mut message_channel_bindings_, owner)
	})
}

fn (mut runtime Runtime) message_channel_port_wrapper(mut binding MessageChannelBinding, port &html.MessagePort) !voidptr {
	mut native_port := unsafe { &html.MessagePort(port) }
	native_port.set_deserialization_context(runtime.native_clone_deserialization_context())
	wrapper := runtime.javascript_event_target(unsafe { &dom.EventTarget(port) }, binding.prototype)!
	binding.ports[wrapper] = port
	return wrapper
}

fn (mut runtime Runtime) message_channel_operation(mut binding MessageChannelBinding, args []voidptr) !voidptr {
	if args.len < 2 { return error('Missing MessageChannel operation') }
	method := runtime.binding_dom_string(args[0])!
	receiver := args[1]
	if method == 'construct' {
		settings := runtime.scripting_settings_ or { return error('MessageChannel requires its owning settings') }
		channel := html.MessageChannel.create_for_settings(settings)
		binding.channels[receiver] = channel
		runtime.retain_javascript_value(receiver)!
		runtime.message_channel_port_wrapper(mut binding, channel.port1())!
		runtime.message_channel_port_wrapper(mut binding, channel.port2())!
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	}
	if method in ['port1', 'port2'] {
		channel := binding.channels[receiver] or { return runtime.event_binding_type_error('Illegal MessageChannel receiver') }
		return runtime.message_channel_port_wrapper(mut binding, if method == 'port1' {
			channel.port1()
		} else {
			channel.port2()
		})
	}
	if method == 'structuredClone' {
		length := int(binding.clone.number(binding.clone.engine('list_length', [args[3]])!)!)
		mut transfers := []voidptr{cap: length}
		for index in 0 .. length {
			transfers << binding.clone.engine('list_item', [args[3], C.vox_jsc_JSValueMakeNumber(runtime.context, f64(index))])!
		}
		record := binding.transfer.serialize_local_message(args[2], transfers)!
		// Projection roots survive reconstruction; the host call's stack keeps
		// the returned value alive until the caller receives it.
		runtime.prepare_html_script()
		defer { runtime.clean_up_html_script() }
		settings := runtime.scripting_settings_ or { return error('structuredClone requires its owning settings') }
		data := html.structured_deserialize_with_transfer_in_context(record, settings.realm(), runtime.native_clone_deserialization_context()) or { return native_clone_unsupported(err.msg()) }
		mut projection := NativeCloneProjection{bridge: binding.clone}
		defer { projection.release_roots() }
		clone := projection.root(projection.reconstruct(data.deserialized)!)!
		return clone
	}
	if method == 'reportError' {
		settings := runtime.scripting_settings_ or { return error('reportError requires its owning settings') }
		settings.report_an_exception(dom.js_webidl_value(runtime.webidl_value(args[2])!), false)
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	}
	mut port := binding.ports[receiver] or { return runtime.event_binding_type_error('Illegal MessagePort receiver') }
	match method {
		'brand' {}
		'start' { port.start() }
		'close' { port.close() }
		'getHandler' {
			return runtime.javascript_event_handler(unsafe { &dom.EventTarget(port) }, runtime.binding_dom_string(args[2])!)
		}
		'setHandler' {
			name := runtime.binding_dom_string(args[2])!
			callback := runtime.event_callback(args[3], true)!
			handler := if callback == unsafe { nil } {
				?&dom.CallbackType(none)
			} else {
				?&dom.CallbackType(callback)
			}
			if name == 'message' {
				port.set_onmessage(handler)
			} else {
				port.set_onmessageerror(handler)
			}
		}
		'post' {
			length := int(binding.clone.number(binding.clone.engine('list_length', [args[3]])!)!)
			if length > 0 {
				mut transfers := []voidptr{cap: length}
				for index in 0 .. length {
					transfers << binding.clone.engine('list_item', [args[3], C.vox_jsc_JSValueMakeNumber(runtime.context, f64(index))])!
				}
				// Match native MessagePort's preflight before author graph getters.
				mut doomed := false
				for value in transfers {
					if source := runtime.native_message_port(value) {
						if voidptr(source) == voidptr(port) { return native_clone_unsupported('Cannot transfer a MessagePort to itself') }
						if target := port.entangled_port() { if voidptr(source) == voidptr(target) { doomed = true } }
					}
				}
				record := binding.transfer.serialize_local_message(args[2], transfers)!
				if !doomed { port.post_port_message(record) }
				return C.vox_jsc_JSValueMakeUndefined(runtime.context)
			}
			mut projection := NativeCloneProjection{ bridge: binding.clone }
			defer { projection.release_roots() }
			message := projection.project(args[2])!
			port.post_message_without_transfer(*message)!
		}
		else { return error('Unknown MessageChannel operation') }
	}
	return C.vox_jsc_JSValueMakeUndefined(runtime.context)
}
