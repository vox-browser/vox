// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import fetch
import http
import libjs
import platform

@[heap]
struct HeadersIteratorState {
	native &fetch.HeadersIterator
	kind fetch.HeadersIterationKind
mut:
	done bool
}

// Fetch's ByteString preserves Latin-1 code units, not their UTF-8 encoding.
fn headers_byte_string(mut vm libjs.VM, value libjs.Value) !string {
	text := value.to_primitive_string(mut vm)!.utf16
	mut bytes := []u8{cap: text.code_units().len}
	for unit in text.code_units() {
		if unit > 255 { return vm.throw_error(.type_error, 'ByteString contains a character greater than 255') }
		bytes << u8(unit)
	}
	return bytes.bytestr()
}

fn headers_byte_value(mut vm libjs.VM, value string) libjs.Value {
	mut units := []u16{cap: value.len}
	for byte in value.bytes() { units << u16(byte) }
	return libjs.Value.from_string(vm.create_string(libjs.utf16_string_from_code_units(units)))
}

fn headers_pair(mut vm libjs.VM, value libjs.Value) !fetch.HeaderPair {
	if !value.is_object() { return vm.throw_error(.type_error, 'Header pair must be an object') }
	mut iterator := libjs.get_iterator_sync_value(mut vm, value)!
	mut items := []string{}
	for {
		vm.consume_execution_budget()!
		step := libjs.iterator_step_value(mut vm, mut iterator)!
		if step.done { break }
		item := headers_byte_string(mut vm, step.value) or {
			return libjs.iterator_close(mut vm, iterator, libjs.completion_from_error(err)).release_error()
		}
		items << item
	}
	if items.len != 2 { return vm.throw_error(.type_error, 'Header pair must contain exactly two values') }
	return fetch.HeaderPair{name: items[0], value: items[1]}
}

fn headers_init(mut vm libjs.VM, value libjs.Value) ![]fetch.HeaderPair {
	if value.is_undefined() { return []fetch.HeaderPair{} }
	if !value.is_object() { return vm.throw_error(.type_error, 'HeadersInit must be an object') }
	method := value.as_object().get_method(mut vm, libjs.PropertyName.from_symbol(vm.well_known_symbol_iterator()))!
	mut pairs := []fetch.HeaderPair{}
	if !method.is_undefined() {
		mut iterator := libjs.get_iterator_from_method(mut vm, value, method)!
		for {
			vm.consume_execution_budget()!
			step := libjs.iterator_step_value(mut vm, mut iterator)!
			if step.done { return pairs }
			pair := headers_pair(mut vm, step.value) or {
				return libjs.iterator_close(mut vm, iterator, libjs.completion_from_error(err)).release_error()
			}
			pairs << pair
		}
	}
	object := value.as_object()
	for key in object.own_property_keys_checked(mut vm)! {
		vm.consume_execution_budget()!
		if descriptor := object.get_own_property_checked(mut vm, key)!.descriptor {
			if descriptor.enumerable or { false } {
				name := headers_byte_string(mut vm, key.to_value(mut vm))!
				text := headers_byte_string(mut vm, object.get(mut vm, key)!)!
				pairs << fetch.HeaderPair{name: name, value: text}
			}
		}
	}
	return pairs
}

fn (mut host Host) wrap_headers(native &fetch.Headers, prototype ?&libjs.Object) libjs.Value {
	if wrapper := host.headers_wrappers[voidptr(native)] { return libjs.Value.from_object(wrapper) }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut object := libjs.Object.create(host.realm, prototype or { host.headers_prototype })
	object.class_name = 'Headers'
	host.headers[voidptr(object)] = native
	host.headers_wrappers[voidptr(native)] = object
	return libjs.Value.from_object(object)
}

fn (host &Host) headers_receiver(mut vm libjs.VM) !&fetch.Headers {
	host.require_open(mut vm)!
	if vm.this_value().is_object() {
		if headers := host.headers[voidptr(vm.this_value().as_object())] { return headers }
	}
	return vm.throw_error(.type_error, 'Headers method called on incompatible receiver')
}

fn (mut host Host) install_headers() ! {
	mut vm := host.vm
	mut prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
	host.headers_prototype = prototype
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('Headers')), libjs.attribute_configurable)
	construct := fn [host] (mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
		host.require_open(mut vm)!
		pairs := headers_init(mut vm, vm.argument(0))!
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		native := fetch.Headers.construct(pairs) or { return vm.throw_error(.type_error, err.msg()) }
		parent := new_target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
		mut owner := unsafe { &Host(host) }
		return owner.wrap_headers(native, if parent.is_object() { ?&libjs.Object(parent.as_object()) } else { none }).as_object()
	}
	host.closures << voidptr(construct)
	constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'Headers constructor requires new') }, construct, 0, libjs.PropertyName.from_str('Headers')).object
	mut function := constructor
	function.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	mut global := host.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('Headers'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	for name in ['append', 'set', 'delete', 'get', 'has', 'getSetCookie'] {
		length := if name in ['append', 'set'] { 2 } else if name == 'getSetCookie' { 0 } else { 1 }
		host.method_attributes(mut prototype, name, length, fn [host, name, length] (mut vm libjs.VM) !libjs.Value {
			mut native := host.headers_receiver(mut vm)!
			if vm.argument_count() < length { return vm.throw_error(.type_error, name + ' requires arguments') }
			if name == 'getSetCookie' {
				values := native.get_set_cookie().map(headers_byte_value(mut vm, it))
				return libjs.Value.from_object(libjs.ArrayObject.create_from(mut vm, host.realm, values, host.realm.array_prototype_record())!.object)
			}
			key := headers_byte_string(mut vm, vm.argument(0))!
			value := if length == 2 { headers_byte_string(mut vm, vm.argument(1))! } else { '' }
			if !http.is_header_name(key) { return vm.throw_error(.type_error, 'Invalid header name') }
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			match name {
				'get' { return if text := native.get(key) { headers_byte_value(mut vm, text) } else { libjs.js_null() } }
				'has' { return libjs.Value.from_bool(native.has(key) or { return vm.throw_error(.type_error, err.msg()) }) }
				'append' { native.append(key, value) or { return vm.throw_error(.type_error, err.msg()) } }
				'set' { native.set(key, value) or { return vm.throw_error(.type_error, err.msg()) } }
				else { native.delete(key) or { return vm.throw_error(.type_error, err.msg()) } }
			}
			return libjs.js_undefined()
		}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	}
	host.install_headers_iteration(mut prototype)!
}

fn (mut host Host) install_headers_iteration(mut prototype libjs.Object) ! {
	mut vm := host.vm
	mut iterator_prototype := libjs.Object.create(host.realm, host.realm.iterator_prototype)
	host.headers_iterator_prototype = iterator_prototype
	iterator_prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('Headers Iterator')), libjs.attribute_configurable)
	host.method_attributes(mut iterator_prototype, 'next', 0, fn [host] (mut vm libjs.VM) !libjs.Value {
		host.require_open(mut vm)!
		if vm.this_value().is_object() {
			if mut state := host.headers_iterators[voidptr(vm.this_value().as_object())] {
				if state.done { return libjs.Value.from_object(libjs.create_iterator_result_object(host.realm, libjs.js_undefined(), true, host.realm.object_prototype)) }
				step := state.native.next()
				state.done = step.done
				mut value := libjs.js_undefined()
				if !step.done {
					value = match state.kind {
						.key { headers_byte_value(mut vm, step.name) }
						.value { headers_byte_value(mut vm, step.value) }
						.key_and_value { libjs.Value.from_object(libjs.ArrayObject.create_from(mut vm, host.realm, [headers_byte_value(mut vm, step.name), headers_byte_value(mut vm, step.value)], host.realm.array_prototype_record())!.object) }
					}
				}
				return libjs.Value.from_object(libjs.create_iterator_result_object(host.realm, value, step.done, host.realm.object_prototype))
			}
		}
		return vm.throw_error(.type_error, 'Headers Iterator method called on incompatible receiver')
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	for name, kind in {'keys': fetch.HeadersIterationKind.key, 'values': .value, 'entries': .key_and_value} {
		host.method_attributes(mut prototype, name, 0, fn [host, kind] (mut vm libjs.VM) !libjs.Value {
			native := host.headers_receiver(mut vm)!
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut owner := unsafe { &Host(host) }
			object := libjs.Object.create(host.realm, host.headers_iterator_prototype)
			owner.headers_iterators[voidptr(object)] = &HeadersIteratorState{native: fetch.HeadersIterator.create(native, kind), kind: kind}
			return libjs.Value.from_object(object)
		}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	}
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_iterator()), prototype.get(mut vm, libjs.PropertyName.from_str('entries'))!, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	host.method_attributes(mut prototype, 'forEach', 1, fn [host] (mut vm libjs.VM) !libjs.Value {
		native := host.headers_receiver(mut vm)!
		callback, receiver, object := vm.argument(0), vm.argument(1), vm.this_value()
		if !callback.is_function() { return vm.throw_error(.type_error, 'Headers callback must be callable') }
		mut iterator := fetch.HeadersIterator.create(native, .key_and_value)
		for {
			vm.consume_execution_budget()!
			step := iterator.next()
			if step.done { return libjs.js_undefined() }
			libjs.call(mut vm, callback, receiver, [headers_byte_value(mut vm, step.value), headers_byte_value(mut vm, step.name), object])!
		}
		return libjs.js_undefined()
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
}
