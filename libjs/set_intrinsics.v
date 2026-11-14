// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Runtime/{SetConstructor,SetPrototype,SetIteratorPrototype}.cpp. Set algebra
// methods are a separate translation slice; the core ordered collection and
// observable iterable construction use the ordinary iterator/call machinery.
fn initialize_set_intrinsics(mut vm VM, mut realm Realm) {
	mut prototype := Object.create(realm, realm.object_prototype)
	realm.set_prototype = prototype
	constructor := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype,
		fn (mut vm VM) !Value { return vm.throw_error(.type_error, 'Set constructor requires new') },
		set_constructor_construct, 0, PropertyName.from_str('Set'))
	mut function := constructor.object
	realm.set_constructor = function
	function.define_direct_property(PropertyName.from_str('prototype'), Value.from_object(prototype), 0)
	function.define_native_accessor(mut vm, realm, PropertyName.from_symbol(vm.well_known_symbol_species()), fn (mut vm VM) !Value { return vm.this_value() }, unsafe { nil }, attribute_configurable, realm.function_prototype)
	prototype.define_direct_property(PropertyName.from_str('constructor'), Value.from_object(function), attribute_writable | attribute_configurable)
	prototype.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), Value.from_string(vm.create_string_from_str('Set')), attribute_configurable)
	prototype.define_native_accessor(mut vm, realm, PropertyName.from_str('size'), fn (mut vm VM) !Value { return Value.from_f64(f64(keyed_collection_receiver(mut vm, false)!.size)) }, unsafe { nil }, attribute_configurable, realm.function_prototype)
	install_intrinsic_method(mut vm, realm, mut prototype, 'add', 1, fn (mut vm VM) !Value {
		mut collection := keyed_collection_receiver(mut vm, false)!
		collection.put(vm.argument(0), vm.argument(0))
		return vm.this_value()
	})
	install_intrinsic_method(mut vm, realm, mut prototype, 'has', 1, fn (mut vm VM) !Value { return Value.from_bool(keyed_collection_receiver(mut vm, false)!.find(vm.argument(0)) >= 0) })
	install_intrinsic_method(mut vm, realm, mut prototype, 'delete', 1, fn (mut vm VM) !Value {
		mut collection := keyed_collection_receiver(mut vm, false)!
		return Value.from_bool(collection.remove(vm.argument(0)))
	})
	install_intrinsic_method(mut vm, realm, mut prototype, 'clear', 0, fn (mut vm VM) !Value {
		mut collection := keyed_collection_receiver(mut vm, false)!
		collection.clear()
		return js_undefined()
	})
	install_intrinsic_method(mut vm, realm, mut prototype, 'forEach', 1, fn (mut vm VM) !Value { return keyed_collection_for_each(mut vm, false) })
	mut iterator := Object.create(realm, realm.iterator_prototype)
	realm.set_iterator_prototype = iterator
	iterator.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), Value.from_string(vm.create_string_from_str('Set Iterator')), attribute_configurable)
	install_intrinsic_method(mut vm, realm, mut iterator, 'next', 0, fn (mut vm VM) !Value { return keyed_iterator_next(mut vm, false) })
	for name, kind in { 'values': PropertyKind.value, 'entries': .key_and_value } {
		method := NativeFunction.create(mut vm, realm, realm.function_prototype, fn [kind] (mut vm VM) !Value {
			return create_keyed_iterator(mut vm, false, kind, vm.realm().set_iterator_prototype or { panic('Missing Set iterator prototype') })
		}, 0, PropertyName.from_str(name), none)
		prototype.define_direct_property(PropertyName.from_str(name), Value.from_object(method.object), attribute_writable | attribute_configurable)
		if kind == .value {
			prototype.define_direct_property(PropertyName.from_str('keys'), Value.from_object(method.object), attribute_writable | attribute_configurable)
			prototype.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_iterator()), Value.from_object(method.object), attribute_writable | attribute_configurable)
		}
	}
}

fn set_constructor_construct(mut vm VM, new_target &Object) !&Object {
	prototype := get_prototype_from_constructor(mut vm, new_target, fn (realm &Realm) &Object { return realm.set_prototype or { panic('Missing Set prototype') } })!
	mut object := Object.create(vm.realm(), prototype)
	object.keyed_collection = &KeyedCollection{ object: object }
	iterable := vm.argument(0)
	if iterable.is_nullish() { return object }
	adder := object.get(mut vm, PropertyName.from_str('add'))!
	if !adder.is_function() { return vm.throw_error_type(.type_error, .not_a_function, 'Set add') }
	mut iterator := get_iterator_sync_value(mut vm, iterable)!
	for {
		vm.consume_execution_budget()!
		step := iterator_step_value(mut vm, mut iterator)!
		if step.done { return object }
		call(mut vm, adder, Value.from_object(object), [step.value]) or {
			return iterator_close(mut vm, iterator, completion_from_error(err)).release_error()
		}
	}
	return object
}
