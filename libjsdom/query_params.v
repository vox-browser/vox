// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import domurl
import libjs
import platform

@[heap]
struct QueryIteratorBinding {
	native &domurl.URLSearchParamsIterator
	kind domurl.URLSearchParamsIteratorKind
mut:
	done bool
}

fn query_usv(mut vm libjs.VM, value libjs.Value) !string {
	return value.to_primitive_string(mut vm)!.utf16.to_well_formed().str()
}

// The upstream generated WebIDL sequence conversion caches next and propagates
// element-conversion failures directly, without IteratorClose. Native pair-size
// validation happens only after conversion of the entire nested sequence.
fn query_pair(mut vm libjs.VM, value libjs.Value) ![]string {
	if !value.is_object() { return vm.throw_error(.type_error, 'URLSearchParams pair must be an object') }
	mut iterator := libjs.get_iterator_sync_value(mut vm, value)!
	mut pair := []string{}
	for {
		vm.consume_execution_budget()!
		step := libjs.iterator_step_value(mut vm, mut iterator)!
		if step.done { break }
		pair << query_usv(mut vm, step.value)!
	}
	return pair
}

fn query_init(mut vm libjs.VM, value libjs.Value) !&domurl.URLSearchParams {
	if value.is_undefined() { return domurl.URLSearchParams.from_string('') }
	if !value.is_object() { return domurl.URLSearchParams.from_string(query_usv(mut vm, value)!) }
	object := value.as_object()
	method := object.get_method(mut vm, libjs.PropertyName.from_symbol(vm.well_known_symbol_iterator()))!
	if !method.is_undefined() {
		mut iterator := libjs.get_iterator_from_method(mut vm, value, method)!
		mut pairs := [][]string{}
		for {
			vm.consume_execution_budget()!
			step := libjs.iterator_step_value(mut vm, mut iterator)!
			if step.done { break }
			pairs << query_pair(mut vm, step.value)!
		}
		return domurl.URLSearchParams.from_sequence(pairs) or { return vm.throw_error(.type_error, 'Expected each pair to contain exactly 2 items') }
	}
	mut record := map[string]string{}
	for key in object.own_property_keys() {
		vm.consume_execution_budget()!
		if descriptor := object.internal_get_own_property(key) {
			if descriptor.enumerable or { false } {
				name := query_usv(mut vm, key.to_value(mut vm))!
				text := query_usv(mut vm, object.get(mut vm, key)!)!
				record[name] = text
			}
		}
	}
	return domurl.URLSearchParams.from_record(record)
}

fn (mut host Host) wrap_query(native &domurl.URLSearchParams, prototype ?&libjs.Object) libjs.Value {
	if object := host.query_wrappers[voidptr(native)] { return libjs.Value.from_object(object) }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut object := libjs.Object.create(host.realm, prototype or { host.query_prototype })
	object.class_name = 'URLSearchParams'
	host.queries[voidptr(object)] = native
	host.query_wrappers[voidptr(native)] = object
	return libjs.Value.from_object(object)
}

fn (host &Host) query_receiver(mut vm libjs.VM) !&domurl.URLSearchParams {
	host.require_open(mut vm)!
	if vm.this_value().is_object() {
		if native := host.queries[voidptr(vm.this_value().as_object())] { return native }
	}
	return vm.throw_error(.type_error, 'URLSearchParams method called on incompatible receiver')
}

fn (mut host Host) install_query_params() ! {
	mut vm := host.vm
	mut prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
	host.query_prototype = prototype
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('URLSearchParams')), libjs.attribute_configurable)
	construct := fn [host] (mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
		host.require_open(mut vm)!
		parent := new_target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		native := query_init(mut vm, vm.argument(0))!
		mut owner := unsafe { &Host(host) }
		return owner.wrap_query(native, if parent.is_object() { ?&libjs.Object(parent.as_object()) } else { none }).as_object()
	}
	host.closures << voidptr(construct)
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'URLSearchParams constructor requires new') }, construct, 0, libjs.PropertyName.from_str('URLSearchParams')).object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	mut global := host.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('URLSearchParams'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	host.accessor(mut prototype, 'size', fn [host] (mut vm libjs.VM) !libjs.Value {
		return libjs.Value.from_f64(f64(host.query_receiver(mut vm)!.size()))
	}, unsafe { nil })
	for name in ['append', 'delete', 'get', 'getAll', 'has', 'set', 'sort', 'toString'] {
		length := if name in ['append', 'set'] { 2 } else if name in ['sort', 'toString'] { 0 } else { 1 }
		host.method_attributes(mut prototype, name, length, fn [host, name, length] (mut vm libjs.VM) !libjs.Value {
			mut native := host.query_receiver(mut vm)!
			if vm.argument_count() < length { return vm.throw_error(.type_error, name + ' requires arguments') }
			key := if length > 0 { query_usv(mut vm, vm.argument(0))! } else { '' }
			mut value := ?string(none)
			if length == 2 || (name in ['has', 'delete'] && !vm.argument(1).is_undefined()) { value = query_usv(mut vm, vm.argument(1))! }
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			match name {
				'get' { return if text := native.get(key) { libjs.Value.from_string(vm.create_string_from_str(text)) } else { libjs.js_null() } }
				'getAll' {
					values := native.get_all(key).map(libjs.Value.from_string(vm.create_string_from_str(it)))
					return libjs.Value.from_object(libjs.ArrayObject.create_from(mut vm, host.realm, values, host.realm.array_prototype_record())!.object)
				}
				'has' { return libjs.Value.from_bool(native.has(key, value)) }
				'append' { native.append(key, value or { '' }) }
				'set' { native.set(key, value or { '' }) }
				'delete' { native.delete_(key, value) }
				'sort' { native.sort() }
				else { return libjs.Value.from_string(vm.create_string_from_str(native.to_string())) }
			}
			return libjs.js_undefined()
		}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	}
	host.install_query_iteration(mut prototype)!
}

fn (mut host Host) install_query_iteration(mut prototype libjs.Object) ! {
	mut vm := host.vm
	mut iterator_prototype := libjs.Object.create(host.realm, host.realm.iterator_prototype)
	host.query_iterator_prototype = iterator_prototype
	iterator_prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('URLSearchParams Iterator')), libjs.attribute_configurable)
	host.method_attributes(mut iterator_prototype, 'next', 0, fn [host] (mut vm libjs.VM) !libjs.Value {
		host.require_open(mut vm)!
		if vm.this_value().is_object() {
			if mut state := host.query_iterators[voidptr(vm.this_value().as_object())] {
				persistent := platform.enter_persistent()
				defer { platform.leave_persistent(persistent) }
				mut value := libjs.js_undefined()
				if !state.done {
					step := state.native.next()
					state.done = step.done
					if !step.done {
						value = match state.kind {
							.key { libjs.Value.from_string(vm.create_string_from_str(step.key)) }
							.value { libjs.Value.from_string(vm.create_string_from_str(step.value)) }
							.key_value { libjs.Value.from_object(libjs.ArrayObject.create_from(mut vm, host.realm, [libjs.Value.from_string(vm.create_string_from_str(step.key)), libjs.Value.from_string(vm.create_string_from_str(step.value))], host.realm.array_prototype_record())!.object) }
						}
					}
				}
				return libjs.Value.from_object(libjs.create_iterator_result_object(host.realm, value, state.done, host.realm.object_prototype))
			}
		}
		return vm.throw_error(.type_error, 'URLSearchParams Iterator method called on incompatible receiver')
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	for name, kind in {'keys': domurl.URLSearchParamsIteratorKind.key, 'values': .value, 'entries': .key_value} {
		host.method_attributes(mut prototype, name, 0, fn [host, kind] (mut vm libjs.VM) !libjs.Value {
			native := host.query_receiver(mut vm)!
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut owner := unsafe { &Host(host) }
			object := libjs.Object.create(host.realm, host.query_iterator_prototype)
			owner.query_iterators[voidptr(object)] = &QueryIteratorBinding{native: domurl.URLSearchParamsIterator.create(native, kind), kind: kind}
			return libjs.Value.from_object(object)
		}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	}
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_iterator()), prototype.get(mut vm, libjs.PropertyName.from_str('entries'))!, libjs.attribute_writable | libjs.attribute_configurable)
	host.method_attributes(mut prototype, 'forEach', 1, fn [host] (mut vm libjs.VM) !libjs.Value {
		native := host.query_receiver(mut vm)!
		callback, receiver, object := vm.argument(0), vm.argument(1), vm.this_value()
		if !callback.is_function() { return vm.throw_error(.type_error, 'URLSearchParams callback must be callable') }
		mut iterator := domurl.URLSearchParamsIterator.create(native, .key_value)
		for {
			vm.consume_execution_budget()!
			step := iterator.next()
			if step.done { break }
			libjs.call(mut vm, callback, receiver, [libjs.Value.from_string(vm.create_string_from_str(step.value)), libjs.Value.from_string(vm.create_string_from_str(step.key)), object])!
		}
		return libjs.js_undefined()
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
}
