// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Runtime/{MapConstructor,MapPrototype,MapIteratorPrototype}.cpp: core Map
// construction, access, mutation and live ordered iteration. Grouping and
// getOrInsert extensions remain separate translation slices.
fn initialize_map_intrinsics(mut vm VM, mut realm Realm) {
	mut prototype := Object.create(realm, realm.object_prototype)
	realm.map_prototype = prototype
	constructor := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype,
		fn (mut vm VM) !Value { return vm.throw_error(.type_error, 'Map constructor requires new') },
		map_constructor_construct, 0, PropertyName.from_str('Map'))
	mut function := constructor.object
	realm.map_constructor = function
	function.define_direct_property(PropertyName.from_str('prototype'), Value.from_object(prototype), 0)
	function.define_native_accessor(mut vm, realm, PropertyName.from_symbol(vm.well_known_symbol_species()), fn (mut vm VM) !Value { return vm.this_value() }, unsafe { nil }, attribute_configurable, realm.function_prototype)
	prototype.define_direct_property(PropertyName.from_str('constructor'), Value.from_object(function), attribute_writable | attribute_configurable)
	prototype.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), Value.from_string(vm.create_string_from_str('Map')), attribute_configurable)
	prototype.define_native_accessor(mut vm, realm, PropertyName.from_str('size'), fn (mut vm VM) !Value { return Value.from_f64(f64(keyed_collection_receiver(mut vm, true)!.size)) }, unsafe { nil }, attribute_configurable, realm.function_prototype)
	install_intrinsic_method(mut vm, realm, mut prototype, 'get', 1, fn (mut vm VM) !Value {
		collection := keyed_collection_receiver(mut vm, true)!
		index := collection.find(vm.argument(0))
		return if index < 0 { js_undefined() } else { collection.entries[index].value }
	})
	install_intrinsic_method(mut vm, realm, mut prototype, 'set', 2, fn (mut vm VM) !Value {
		mut collection := keyed_collection_receiver(mut vm, true)!
		collection.put(vm.argument(0), vm.argument(1))
		return vm.this_value()
	})
	install_intrinsic_method(mut vm, realm, mut prototype, 'has', 1, fn (mut vm VM) !Value { return Value.from_bool(keyed_collection_receiver(mut vm, true)!.find(vm.argument(0)) >= 0) })
	install_intrinsic_method(mut vm, realm, mut prototype, 'delete', 1, fn (mut vm VM) !Value {
		mut collection := keyed_collection_receiver(mut vm, true)!
		return Value.from_bool(collection.remove(vm.argument(0)))
	})
	install_intrinsic_method(mut vm, realm, mut prototype, 'clear', 0, fn (mut vm VM) !Value {
		mut collection := keyed_collection_receiver(mut vm, true)!
		collection.clear()
		return js_undefined()
	})
	install_intrinsic_method(mut vm, realm, mut prototype, 'forEach', 1, fn (mut vm VM) !Value { return keyed_collection_for_each(mut vm, true) })
	mut iterator := Object.create(realm, realm.iterator_prototype)
	realm.map_iterator_prototype = iterator
	iterator.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), Value.from_string(vm.create_string_from_str('Map Iterator')), attribute_configurable)
	install_keyed_iterator_next(mut vm, realm, mut iterator, true)
	for name, kind in { 'keys': PropertyKind.key, 'values': .value, 'entries': .key_and_value } {
		method := NativeFunction.create(mut vm, realm, realm.function_prototype, fn [kind] (mut vm VM) !Value {
			return create_keyed_iterator(mut vm, true, kind, vm.realm().map_iterator_prototype or { panic('Missing Map iterator prototype') })
		}, 0, PropertyName.from_str(name), none)
		prototype.define_direct_property(PropertyName.from_str(name), Value.from_object(method.object), attribute_writable | attribute_configurable)
		if kind == .key_and_value {
			prototype.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_iterator()), Value.from_object(method.object), attribute_writable | attribute_configurable)
		}
	}
}

fn map_constructor_construct(mut vm VM, new_target &Object) !&Object {
	prototype := get_prototype_from_constructor(mut vm, new_target, fn (realm &Realm) &Object { return realm.map_prototype or { panic('Missing Map prototype') } })!
	mut object := Object.create(vm.realm(), prototype)
	object.keyed_collection = &KeyedCollection{ object: object, is_map: true }
	iterable := vm.argument(0)
	if iterable.is_nullish() { return object }
	adder := object.get(mut vm, PropertyName.from_str('set'))!
	if !adder.is_function() { return vm.throw_error_type(.type_error, .not_a_function, 'Map set') }
	mut iterator := get_iterator_sync_value(mut vm, iterable)!
	for {
		vm.consume_execution_budget()!
		step := iterator_step_value(mut vm, mut iterator)!
		if step.done { return object }
		map_constructor_add_entry(mut vm, object, adder, step.value) or {
			return iterator_close(mut vm, iterator, completion_from_error(err)).release_error()
		}
	}
	return object
}

fn map_constructor_add_entry(mut vm VM, map_ &Object, adder Value, entry Value) ! {
	if !entry.is_object() { return vm.throw_error(.type_error, 'Map iterator value is not an object') }
	object := entry.as_object()
	key := object.get(mut vm, PropertyName.from_number(0))!
	value := object.get(mut vm, PropertyName.from_number(1))!
	call(mut vm, adder, Value.from_object(map_), [key, value])!
}
