// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import platform

fn (host &Host) message_event_receiver(mut vm libjs.VM) !&html.MessageEvent {
	event := host.event(mut vm)!
	if event.interface_ != .message_event { return vm.throw_error(.type_error, 'Expected a MessageEvent') }
	return unsafe { &html.MessageEvent(event) }
}

fn (host &Host) message_event_source(mut vm libjs.VM, value libjs.Value) !html.MessageEventSource {
	if value.is_object() && voidptr(value.as_object()) == voidptr(host.realm.global_object_record()) {
		mut owner := unsafe { &Host(host) }
		owner.frame_window(mut vm)!
		proxy := host.document.default_view() or { return vm.throw_error(.type_error, 'Window has no associated proxy') }
		return html.MessageEventSource(html.WindowMessageEventSource{value: proxy})
	}
	port := host.message_port_value(mut vm, value)!
	return html.MessageEventSource(html.PortMessageEventSource{value: port})
}

fn (host &Host) message_event_port_list(mut vm libjs.VM, value libjs.Value) ![]&html.MessagePort {
	if value.is_undefined() { return [] }
	if !value.is_object() { return vm.throw_error(.type_error, 'Expected an iterable of MessagePorts') }
	key := libjs.PropertyName.from_symbol(vm.well_known_symbol_iterator())
	iterator := value.as_object().get_method(mut vm, key)!
	return host.message_port_sequence(mut vm, value, iterator)
}

fn (mut host Host) install_message_events() ! {
	mut prototype := libjs.Object.create(host.realm, host.event_prototype)
	host.message_event_prototype = prototype
	host.register_event_interface(mut prototype, 'MessageEvent', 'Event', fn [host] (mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
		host.require_open(mut vm)!
		if vm.argument_count() == 0 { return vm.throw_error(.type_error, 'MessageEvent requires a type') }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		type_ := vm.argument(0).to_primitive_string(mut vm)!.str()
		options := vm.argument(1)
		if !options.is_nullish() && !options.is_object() {
			return vm.throw_error(.type_error, 'MessageEventInit must be a dictionary')
		}
		bubbles := text_encoding_member(mut vm, options, 'bubbles')!.to_boolean()
		cancelable := text_encoding_member(mut vm, options, 'cancelable')!.to_boolean()
		composed := text_encoding_member(mut vm, options, 'composed')!.to_boolean()
		data := text_encoding_member(mut vm, options, 'data')!
		last := text_encoding_member(mut vm, options, 'lastEventId')!
		last_id := if last.is_undefined() { '' } else { last.to_primitive_string(mut vm)!.str() }
		address := text_encoding_member(mut vm, options, 'origin')!
		origin := if address.is_undefined() { '' } else { query_usv(mut vm, address)! }
		ports := host.message_event_port_list(mut vm, text_encoding_member(mut vm, options, 'ports')!)!
		source_value := text_encoding_member(mut vm, options, 'source')!
		source := if source_value.is_nullish() { ?html.MessageEventSource(none) }
			else { ?html.MessageEventSource(host.message_event_source(mut vm, source_value)!) }
		parent := new_target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
		mut owner := unsafe { &Host(host) }
		event := html.MessageEvent.create(type_, html.MessageEventInit{
			EventInit: dom.EventInit{bubbles: bubbles, cancelable: cancelable, composed: composed}
			data: owner.native_abort_reason(if data.is_undefined() { libjs.js_null() } else { data })
			origin: origin
			last_event_id: last_id
			ports: ports
			source: source
		})
		mut object := libjs.Object.create(host.realm, if parent.is_object() { parent.as_object() } else { host.message_event_prototype })
		return owner.register_event_wrapper(mut object, unsafe { &dom.Event(event) }).as_object()
	})!
	for name in ['data', 'origin', 'lastEventId', 'source', 'ports'] {
		host.accessor(mut prototype, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			event := host.message_event_receiver(mut vm)!
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut owner := unsafe { &Host(host) }
			match name {
				'data' { return owner.message_event_value(mut vm, event) }
				'origin' { return libjs.Value.from_string(vm.create_string_from_str(event.origin())) }
				'lastEventId' { return libjs.Value.from_string(vm.create_string_from_str(event.last_event_id())) }
				'source' {
					source := event.source() or { return libjs.js_null() }
					return match source {
						html.PortMessageEventSource { owner.wrap_message_port(source.value) }
						html.WindowMessageEventSource {
							proxy := owner.document.default_view() or { return libjs.js_null() }
							if voidptr(source.value) == voidptr(proxy) { libjs.Value.from_object(host.realm.global_object_record()) }
							else { libjs.js_null() }
						}
					}
				}
				else { return owner.message_event_port_value(mut vm, event) }
			}
		}, unsafe { nil })
	}
	host.method_attributes(mut prototype, 'initMessageEvent', 1, fn [host] (mut vm libjs.VM) !libjs.Value {
		mut event := host.message_event_receiver(mut vm)!
		if vm.argument_count() == 0 { return vm.throw_error(.type_error, 'initMessageEvent requires a type') }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		type_ := vm.argument(0).to_primitive_string(mut vm)!.str()
		bubbles := vm.argument(1).to_boolean()
		cancelable := vm.argument(2).to_boolean()
		data := if vm.argument(3).is_undefined() { libjs.js_null() } else { vm.argument(3) }
		origin := if vm.argument(4).is_undefined() { '' } else { query_usv(mut vm, vm.argument(4))! }
		last_id := if vm.argument(5).is_undefined() { '' } else { vm.argument(5).to_primitive_string(mut vm)!.str() }
		source := if vm.argument(6).is_nullish() { ?html.MessageEventSource(none) }
			else { ?html.MessageEventSource(host.message_event_source(mut vm, vm.argument(6))!) }
		ports := host.message_event_port_list(mut vm, vm.argument(7))!
		if !event.dispatched() {
			mut owner := unsafe { &Host(host) }
			event.init_message_event(type_, bubbles, cancelable, owner.native_abort_reason(data),
				origin, last_id, source, ports)
			owner.message_event_data.delete(voidptr(event))
			owner.message_event_ports.delete(voidptr(event))
		}
		return libjs.js_undefined()
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
}

fn (mut host Host) message_event_value(mut vm libjs.VM, event &html.MessageEvent) !libjs.Value {
	data := event.data()
	if raw := data.native_value_ {
		if raw.runtime_value_ != none { return host.abort_reason_value(mut vm, raw) }
	}
	if value := host.message_event_data[voidptr(event)] { return value }
	mut clone := HistoryClone{host: &host, message_ports: true}
	value := clone.reconstruct(mut vm, data, 0) or { return host.dom_error(mut vm, err) }
	if data.is_structured_object() { host.message_event_data[voidptr(event)] = value }
	return value
}

fn (mut host Host) message_event_port_value(mut vm libjs.VM, event &html.MessageEvent) !libjs.Value {
	if value := host.message_event_ports[voidptr(event)] { return value }
	mut ports := []libjs.Value{}
	for port in event.ports() { ports << host.wrap_message_port(port) }
	mut array := libjs.ArrayObject.create_from(mut vm, host.realm, ports, host.realm.array_prototype_record())!.object
	if !array.set_integrity_level(mut vm, .frozen)! {
		return vm.throw_error(.type_error, 'Unable to freeze MessageEvent ports')
	}
	value := libjs.Value.from_object(array)
	host.message_event_ports[voidptr(event)] = value
	return value
}
