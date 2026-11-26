// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Runtime/WeakMapConstructor.cpp and WeakMapPrototype.cpp, including the
// source's upsert operations. Iterable construction preserves observable
// adder lookup, entry getters and abrupt iterator closing.
fn initialize_weak_map_intrinsics(mut vm VM, mut realm Realm) {
	mut prototype := Object.create(realm, realm.object_prototype)
	realm.weak_map_prototype = prototype
	constructor := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype,
		fn (mut vm VM) !Value { return vm.throw_error(.type_error, 'WeakMap constructor requires new') },
		weak_map_construct, 0, PropertyName.from_str('WeakMap'))
	mut function := constructor.object
	realm.weak_map_constructor = function
	function.define_direct_property(PropertyName.from_str('prototype'), Value.from_object(prototype), 0)
	prototype.define_direct_property(PropertyName.from_str('constructor'), Value.from_object(function), attribute_writable | attribute_configurable)
	for name in ['delete', 'get', 'getOrInsert', 'getOrInsertComputed', 'has', 'set'] {
		install_intrinsic_method(mut vm, realm, mut prototype, name, if name in ['set', 'getOrInsert', 'getOrInsertComputed'] { 2 } else { 1 }, fn [name] (mut vm VM) !Value {
			mut collection := weak_map_receiver(mut vm)!
			key := vm.argument(0)
			if name in ['set', 'getOrInsert', 'getOrInsertComputed'] && !can_be_held_weakly(key) { return vm.throw_error_type(.type_error, .cannot_be_held_weakly, key.str()) }
			if name == 'getOrInsertComputed' && !vm.argument(1).is_function() { return vm.throw_error_type(.type_error, .not_a_function, vm.argument(1).str()) }
			if name == 'delete' { return Value.from_bool(collection.remove(key)) }
			if name != 'set' {
				if value := collection.get(key) { return if name == 'has' { Value.from_bool(true) } else { value } }
				if name == 'get' { return js_undefined() }
				if name == 'has' { return Value.from_bool(false) }
			}
			value := if name == 'getOrInsertComputed' { call(mut vm, vm.argument(1), js_undefined(), [key])! } else { vm.argument(1) }
			collection.put(key, value)!
			return if name == 'set' { vm.this_value() } else { value }
		})
	}
	prototype.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), Value.from_string(vm.create_string_from_str('WeakMap')), attribute_configurable)
}

fn weak_map_construct(mut vm VM, new_target &Object) !&Object {
	prototype := get_prototype_from_constructor(mut vm, new_target, fn (realm &Realm) &Object { return realm.weak_map_prototype or { panic('Missing WeakMap prototype') } })!
	object := create_weak_map(mut vm, prototype)!
	iterable := vm.argument(0)
	if iterable.is_nullish() { return object }
	adder := object.get(mut vm, PropertyName.from_str('set'))!
	if !adder.is_function() { return vm.throw_error_type(.type_error, .not_a_function, 'WeakMap set') }
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
