// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import platform

fn (host &Host) message_port_value(mut vm libjs.VM, value libjs.Value) !&html.MessagePort {
	host.require_open(mut vm)!
	if value.is_object() {
		if port := host.message_ports[voidptr(value.as_object())] { return port }
	}
	return vm.throw_error(.type_error, 'Expected a MessagePort')
}

fn (mut host Host) wrap_message_port(port &html.MessagePort) libjs.Value {
	if object := host.event_target_wrappers[voidptr(port)] {
		return libjs.Value.from_object(object)
	}
	mut object := libjs.Object.create(host.realm, host.message_port_prototype)
	object.class_name = 'MessagePort'
	target := unsafe { &dom.EventTarget(port) }
	host.message_ports[voidptr(object)] = port
	host.event_targets[voidptr(object)] = target
	host.event_target_wrappers[voidptr(target)] = object
	return libjs.Value.from_object(object)
}

fn (host &Host) message_port_sequence(mut vm libjs.VM, value libjs.Value, method libjs.Value) ![]&html.MessagePort {
	if !value.is_object() || method.is_undefined() {
		return vm.throw_error(.type_error, 'Expected an iterable of MessagePorts')
	}
	mut iterator := libjs.get_iterator_from_method(mut vm, value, method)!
	mut ports := []&html.MessagePort{}
	for {
		item := libjs.iterator_step_value(mut vm, mut iterator)!
		if item.done { return ports }
		port := host.message_port_value(mut vm, item.value) or {
			return libjs.iterator_close(mut vm, iterator, libjs.completion_from_error(err)).release_error()
		}
		ports << port
	}
	return ports
}

fn (host &Host) message_port_transfers(mut vm libjs.VM, arg libjs.Value) ![]&html.MessagePort {
	if arg.is_nullish() { return [] }
	if !arg.is_object() { return vm.throw_error(.type_error, 'Expected MessagePort transfer options') }
	key := libjs.PropertyName.from_symbol(vm.well_known_symbol_iterator())
	method := arg.as_object().get_method(mut vm, key)!
	value := if method.is_undefined() {
		arg.as_object().get(mut vm, libjs.PropertyName.from_str('transfer'))!
	} else {
		arg
	}
	if value.is_undefined() { return [] }
	if !value.is_object() { return vm.throw_error(.type_error, 'Expected a transfer sequence') }
	iterator := if method.is_undefined() { value.as_object().get_method(mut vm, key)! } else { method }
	return host.message_port_sequence(mut vm, value, iterator)
}

fn (mut host Host) install_message_channels() ! {
	mut prototype := libjs.Object.create(host.realm, host.event_target_prototype)
	host.message_port_prototype = prototype
	host.register_platform_constructor(mut prototype, 'MessagePort', host.event_target_constructor, 0,
		fn (mut vm libjs.VM, _ &libjs.Object) !&libjs.Object {
			return vm.throw_error(.type_error, 'Illegal MessagePort constructor')
		})
	host.install_message_port_methods(mut prototype)
	host.install_message_events()!

	mut channel_prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
	host.message_channel_prototype = channel_prototype
	host.register_platform_constructor(mut channel_prototype, 'MessageChannel', host.realm.function_prototype, 0,
		fn [host] (mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
			host.require_open(mut vm)!
			parent := new_target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut owner := unsafe { &Host(host) }
			owner.frame_window(mut vm)!
			settings := unsafe { &html.EnvironmentSettingsObject(owner.document.relevant_settings_object()) }
			channel := html.MessageChannel.create_for_settings(settings)
			mut object := libjs.Object.create(host.realm, if parent.is_object() { parent.as_object() } else { host.message_channel_prototype })
			object.class_name = 'MessageChannel'
			owner.message_channels[voidptr(object)] = channel
			return object
		})
	for name in ['port1', 'port2'] {
		host.accessor(mut channel_prototype, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			host.require_open(mut vm)!
			value := vm.this_value()
			if !value.is_object() { return vm.throw_error(.type_error, 'Expected a MessageChannel') }
			channel := host.message_channels[voidptr(value.as_object())] or {
				return vm.throw_error(.type_error, 'Expected a MessageChannel')
			}
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut owner := unsafe { &Host(host) }
			return owner.wrap_message_port(if name == 'port1' { channel.port1() } else { channel.port2() })
		}, unsafe { nil })
	}
}

fn (mut host Host) install_message_port_methods(mut prototype libjs.Object) {
	attributes := libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable
	host.method_attributes(mut prototype, 'postMessage', 1, fn [host] (mut vm libjs.VM) !libjs.Value {
		port := host.message_port_value(mut vm, vm.this_value())!
		if vm.argument_count() == 0 { return vm.throw_error(.type_error, 'MessagePort.postMessage requires a message') }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		ports := host.message_port_transfers(mut vm, vm.argument(1))!
		mut owner := unsafe { &Host(host) }
		// The existing ordinary-object projection preserves aliases and cycles.
		mut clone := HistoryClone{host: owner}
		mut transfers := []html.StructuredTransfer{cap: ports.len}
		mut memory := []&html.StructuredObject{cap: ports.len}
		for transferred in ports {
			if voidptr(transferred) == voidptr(port) || transferred.is_detached() {
				return owner.dom_error(mut vm, error('DataCloneError: cannot transfer this MessagePort'))
			}
			object := host.event_target_wrappers[voidptr(transferred)] or {
				return vm.throw_error(.type_error, 'MessagePort wrapper is unavailable')
			}
			if voidptr(object) in clone.input {
				return owner.dom_error(mut vm, error('DataCloneError: duplicate MessagePort transfer'))
			}
			entry := &html.StructuredObject{kind: .message_port, message_port_: transferred}
			transfers << html.StructuredTransfer(html.MessagePortTransfer{value: transferred})
			memory << entry
			projected := html.structured_object_value(entry)
			clone.input[voidptr(object)] = &projected
		}
		message := clone.project(mut vm, vm.argument(0), 0) or { return owner.dom_error(mut vm, err) }
		port.post_message_with_transfer_memory(message, html.StructuredSerializeOptions{transfer: transfers}, memory) or {
			return owner.dom_error(mut vm, err)
		}
		return libjs.js_undefined()
	}, attributes)
	for name in ['start', 'close'] {
		host.method_attributes(mut prototype, name, 0, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			mut port := host.message_port_value(mut vm, vm.this_value())!
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			if name == 'start' { port.start() } else { port.close() }
			return libjs.js_undefined()
		}, attributes)
	}
	for type_ in ['message', 'messageerror'] {
		host.accessor(mut prototype, 'on' + type_, fn [host, type_] (mut vm libjs.VM) !libjs.Value {
			port := host.message_port_value(mut vm, vm.this_value())!
			if callback := port.event_handler_attribute(type_) {
				for listener in host.listeners {
					if listener.attribute && voidptr(listener.native.callback()) == voidptr(callback) { return listener.callback }
				}
			}
			return libjs.js_null()
		}, fn [host, type_] (mut vm libjs.VM) !libjs.Value {
			mut port := host.message_port_value(mut vm, vm.this_value())!
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut owner := unsafe { &Host(host) }
			target := unsafe { &dom.EventTarget(port) }
			for index := owner.listeners.len - 1; index >= 0; index-- {
				listener := owner.listeners[index]
				if listener.attribute && listener.type_ == type_ && voidptr(listener.target) == voidptr(port) {
					owner.listeners.delete(index)
				}
			}
			value := vm.argument(0)
			if value.is_function() {
				owner.add_listener(target, type_, value, dom.AddEventListenerOptions{}, true)
			} else {
				target.set_event_handler_attribute(type_, none)
			}
			if type_ == 'message' { port.start() }
			return libjs.js_undefined()
		})
	}
}

fn (mut host Host) close_message_channels() {
	if host.message_channels.len != 0 || host.message_ports.len != 0 {
		settings := host.document.relevant_settings_object()
		if settings != unsafe { nil } {
			html.retire_message_ports_for_settings(unsafe { &html.EnvironmentSettingsObject(settings) })
		}
	}
	host.message_channels.clear()
	host.message_ports.clear()
	host.message_event_data.clear()
	host.message_event_ports.clear()
}
