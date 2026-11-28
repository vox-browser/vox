// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import css
import dom
import libjs
import platform

fn (host &Host) media_query_receiver(mut vm libjs.VM) !&css.MediaQueryList {
	host.require_open(mut vm)!
	if vm.this_value().is_object() {
		if native := host.media_queries[voidptr(vm.this_value().as_object())] { return native }
	}
	return vm.throw_error(.type_error, 'MediaQueryList member called on incompatible receiver')
}

fn (mut host Host) install_media_queries() ! {
	mut vm := host.vm
	mut prototype := libjs.Object.create(host.realm, host.event_target_prototype)
	host.media_query_prototype = prototype
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('MediaQueryList')), libjs.attribute_configurable)
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.event_target_constructor,
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'Illegal MediaQueryList constructor') },
		fn (mut vm libjs.VM, _ &libjs.Object) !&libjs.Object { return vm.throw_error(.type_error, 'Illegal MediaQueryList constructor') }, 0, libjs.PropertyName.from_str('MediaQueryList')).object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	for name in ['media', 'matches'] {
		host.accessor(mut prototype, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			native := host.media_query_receiver(mut vm)!
			if name == 'matches' { return libjs.Value.from_bool(native.matches()) }
			return libjs.Value.from_string(vm.create_string(libjs.utf16_string_from_utf8_without_validation(native.media())))
		}, unsafe { nil })
	}
	for name in ['addListener', 'removeListener'] {
		host.method_attributes(mut prototype, name, 1, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			native := host.media_query_receiver(mut vm)!
			if vm.argument_count() == 0 { return vm.throw_error(.type_error, name + ' requires a listener') }
			callback := vm.argument(0)
			if callback.is_nullish() { return libjs.js_undefined() }
			if !callback.is_object() { return vm.throw_error(.type_error, 'EventListener must be an object') }
			mut owner := unsafe { &Host(host) }
			target := unsafe { &dom.EventTarget(native) }
			if name == 'addListener' { owner.add_listener(target, 'change', callback, dom.AddEventListenerOptions{}, false) }
			else { owner.remove_listener(target, 'change', callback, false) }
			return libjs.js_undefined()
		}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	}
	host.accessor(mut prototype, 'onchange', fn [host] (mut vm libjs.VM) !libjs.Value {
		target := voidptr(host.media_query_receiver(mut vm)!)
		for listener in host.listeners {
			if listener.attribute && listener.type_ == 'change' && voidptr(listener.target) == target { return listener.callback }
		}
		return libjs.js_null()
	}, fn [host] (mut vm libjs.VM) !libjs.Value {
		target := unsafe { &dom.EventTarget(host.media_query_receiver(mut vm)!) }
		mut owner := unsafe { &Host(host) }
		for index := owner.listeners.len - 1; index >= 0; index-- {
			listener := owner.listeners[index]
			if listener.attribute && listener.type_ == 'change' && voidptr(listener.target) == voidptr(target) { owner.listeners.delete(index) }
		}
		target.set_event_handler_attribute('change', none)
		if vm.argument(0).is_function() { owner.add_listener(target, 'change', vm.argument(0), dom.AddEventListenerOptions{}, true) }
		return libjs.js_undefined()
	})
	mut global := host.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('MediaQueryList'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	host.method_attributes(mut global, 'matchMedia', 1, fn [host] (mut vm libjs.VM) !libjs.Value {
		host.window_receiver(mut vm)!
		if vm.argument_count() == 0 { return vm.throw_error(.type_error, 'matchMedia requires a query') }
		query := vm.argument(0).to_primitive_string(mut vm)!.str()
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut owner := unsafe { &Host(host) }
		window := owner.frame_window(mut vm)!
		native := window.match_media(query)
		mut object := libjs.Object.create(host.realm, host.media_query_prototype)
		object.class_name = 'MediaQueryList'
		owner.media_queries[voidptr(object)] = native
		owner.event_targets[voidptr(object)] = unsafe { &dom.EventTarget(native) }
		owner.event_target_wrappers[voidptr(native)] = object
		return libjs.Value.from_object(object)
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	host.install_media_query_events()!
}

fn (mut host Host) install_media_query_events() ! {
	mut vm := host.vm
	mut prototype := libjs.Object.create(host.realm, host.event_prototype)
	host.media_event_prototype = prototype
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('MediaQueryListEvent')), libjs.attribute_configurable)
	for name in ['media', 'matches'] {
		host.accessor(mut prototype, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			event := host.event(mut vm)!
			if event.interface_ != .media_query_list_event { return vm.throw_error(.type_error, 'MediaQueryListEvent member called on incompatible receiver') }
			native := unsafe { &css.MediaQueryListEvent(event) }
			if name == 'matches' { return libjs.Value.from_bool(native.matches()) }
			return libjs.Value.from_string(vm.create_string(libjs.utf16_string_from_utf8_without_validation(native.media())))
		}, unsafe { nil })
	}
	construct := fn [host] (mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
		host.require_open(mut vm)!
		if vm.argument_count() == 0 { return vm.throw_error(.type_error, 'MediaQueryListEvent requires a type') }
		type_ := vm.argument(0).to_primitive_string(mut vm)!.str()
		options := vm.argument(1)
		mut init := css.MediaQueryListEventInit{}
		if !options.is_nullish() {
			if !options.is_object() { return vm.throw_error(.type_error, 'MediaQueryListEventInit must be a dictionary') }
			dictionary := options.as_object()
			init.EventInit = dom.EventInit{
				bubbles: dictionary.get(mut vm, libjs.PropertyName.from_str('bubbles'))!.to_boolean()
				cancelable: dictionary.get(mut vm, libjs.PropertyName.from_str('cancelable'))!.to_boolean()
				composed: dictionary.get(mut vm, libjs.PropertyName.from_str('composed'))!.to_boolean()
			}
			init.matches = dictionary.get(mut vm, libjs.PropertyName.from_str('matches'))!.to_boolean()
			media := dictionary.get(mut vm, libjs.PropertyName.from_str('media'))!
			if !media.is_undefined() { init.media = media.to_primitive_string(mut vm)!.str() }
		}
		parent := new_target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut object := libjs.Object.create(host.realm, if parent.is_object() { parent.as_object() } else { host.media_event_prototype })
		native := css.MediaQueryListEvent.construct_impl(type_, init)
		mut owner := unsafe { &Host(host) }
		return owner.register_event_wrapper(mut object, native.base_event()).as_object()
	}
	host.closures << voidptr(construct)
	mut global := host.realm.global_object_record()
	parent := global.get(mut vm, libjs.PropertyName.from_str('Event'))!.as_object()
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, parent,
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'MediaQueryListEvent requires new') }, construct, 1, libjs.PropertyName.from_str('MediaQueryListEvent')).object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	global.define_direct_property(libjs.PropertyName.from_str('MediaQueryListEvent'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
}
