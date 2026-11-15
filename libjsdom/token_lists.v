// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import libjs
import platform

@[heap]
struct TokenListCollection {
	host &Host
	native &dom.DOMTokenList
}

fn token_string(mut vm libjs.VM, text string) libjs.Value {
	return libjs.Value.from_string(vm.create_string(libjs.utf16_string_from_utf8_without_validation(text)))
}

fn (list &TokenListCollection) get_own_property(key libjs.PropertyName) ?libjs.PropertyDescriptor {
	if list.host.closed || !key.is_number() { return none }
	if token := list.native.item(int(key.number)) {
		mut vm := list.host.vm
		return libjs.PropertyDescriptor{value: token_string(mut vm, token), writable: false, enumerable: true, configurable: false}
	}
	return none
}

fn (list &TokenListCollection) own_property_keys() []libjs.PropertyName {
	if list.host.closed { return [] }
	return []libjs.PropertyName{len: list.native.length(), init: libjs.PropertyName.from_number(u32(index))}
}

fn (host &Host) token_list_receiver(mut vm libjs.VM) !&dom.DOMTokenList {
	host.require_open(mut vm)!
	if vm.this_value().is_object() {
		if provider := vm.this_value().as_object().host_properties {
			if provider is TokenListCollection {
				if voidptr(provider.host) == voidptr(host) { return provider.native }
			}
		}
	}
	return vm.throw_error(.type_error, 'DOMTokenList member called on incompatible receiver')
}

fn (mut host Host) wrap_token_list(native &dom.DOMTokenList) libjs.Value {
	if object := host.token_list_wrappers[voidptr(native)] { return libjs.Value.from_object(object) }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut object := libjs.Object.create(host.realm, host.token_list_prototype)
	object.class_name = 'DOMTokenList'
	object.host_properties = libjs.HostProperties(&TokenListCollection{host: &host, native: native})
	host.token_list_wrappers[voidptr(native)] = object
	return libjs.Value.from_object(object)
}

// DOM/DOMTokenList.idl and Element.classList. All storage, token validation and
// attribute updates belong to the native list. Indexed properties stay live.
fn (mut host Host) install_token_lists() ! {
	mut vm := host.vm
	mut prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
	host.token_list_prototype = prototype
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('DOMTokenList')), libjs.attribute_configurable)
	host.accessor(mut prototype, 'length', fn [host] (mut vm libjs.VM) !libjs.Value {
		return libjs.Value.from_f64(f64(host.token_list_receiver(mut vm)!.length()))
	}, unsafe { nil })
	host.accessor(mut prototype, 'value', fn [host] (mut vm libjs.VM) !libjs.Value {
		return token_string(mut vm, host.token_list_receiver(mut vm)!.value())
	}, fn [host] (mut vm libjs.VM) !libjs.Value {
		mut native := host.token_list_receiver(mut vm)!
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		native.set_value(vm.argument(0).to_primitive_string(mut vm)!.str())
		mut owner := unsafe { &Host(host) }
		owner.changed()
		return libjs.js_undefined()
	})
	for name in ['item', 'contains', 'add', 'remove', 'toggle', 'replace', 'supports', 'toString'] {
		length := if name in ['add', 'remove', 'toString'] { 0 } else if name == 'replace' { 2 } else { 1 }
		host.method_attributes(mut prototype, name, length, fn [host, name, length] (mut vm libjs.VM) !libjs.Value {
			mut native := host.token_list_receiver(mut vm)!
			if vm.argument_count() < u32(length) { return vm.throw_error(.type_error, name + ' requires an argument') }
			if name == 'item' {
				index := vm.argument(0).to_u32(mut vm)!
				return if token := native.item(int(index)) { token_string(mut vm, token) } else { libjs.js_null() }
			}
			if name == 'toString' { return token_string(mut vm, native.value()) }
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut owner := unsafe { &Host(host) }
			if name in ['add', 'remove'] {
				mut tokens := []string{cap: int(vm.argument_count())}
				for index in 0 .. vm.argument_count() {
					vm.consume_execution_budget()!
					tokens << vm.argument(index).to_primitive_string(mut vm)!.str()
				}
				if name == 'add' { native.add(tokens) or { return owner.dom_error(mut vm, err) } }
				else { native.remove(tokens) or { return owner.dom_error(mut vm, err) } }
				owner.changed()
				return libjs.js_undefined()
			}
			token := vm.argument(0).to_primitive_string(mut vm)!.str()
			if name == 'contains' { return libjs.Value.from_bool(native.contains(token)) }
			if name == 'supports' { return libjs.Value.from_bool(native.supports(token) or { return owner.dom_error(mut vm, err) }) }
			result := if name == 'toggle' {
				force := if vm.argument_count() > 1 { ?bool(vm.argument(1).to_boolean()) } else { none }
				native.toggle(token, force) or { return owner.dom_error(mut vm, err) }
			} else {
				replacement := vm.argument(1).to_primitive_string(mut vm)!.str()
				native.replace(token, replacement) or { return owner.dom_error(mut vm, err) }
			}
			owner.changed()
			return libjs.Value.from_bool(result)
		}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	}
	for name in ['entries', 'keys', 'values', 'forEach'] {
		method := host.realm.array_prototype_record().get(mut vm, libjs.PropertyName.from_str(name))!
		prototype.define_direct_property(libjs.PropertyName.from_str(name), method, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	}
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_iterator()), host.realm.array_prototype_values, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'Illegal DOMTokenList constructor') },
		fn (mut vm libjs.VM, _ &libjs.Object) !&libjs.Object { return vm.throw_error(.type_error, 'Illegal DOMTokenList constructor') }, 0, libjs.PropertyName.from_str('DOMTokenList')).object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	mut global := host.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('DOMTokenList'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	mut element := host.element_prototype
	host.accessor(mut element, 'classList', fn [host] (mut vm libjs.VM) !libjs.Value {
		mut native := unsafe { &dom.Element(host.element(mut vm)!) }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut owner := unsafe { &Host(host) }
		return owner.wrap_token_list(native.class_list())
	}, fn [host] (mut vm libjs.VM) !libjs.Value {
		mut native := unsafe { &dom.Element(host.element(mut vm)!) }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		// Element.idl's PutForwards=value retains the SameObject wrapper.
		mut list := native.class_list()
		list.set_value(vm.argument(0).to_primitive_string(mut vm)!.str())
		mut owner := unsafe { &Host(host) }
		owner.changed()
		return libjs.js_undefined()
	})
}
