// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Runtime/WeakSetConstructor.cpp and WeakSetPrototype.cpp. Iterable construction
// looks up add once, calls it with the new set, and closes on adder failure.
fn initialize_weak_set_intrinsics(mut vm VM, mut realm Realm) {
	mut prototype := Object.create(realm, realm.object_prototype)
	realm.weak_set_prototype = prototype
	constructor := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype,
		fn (mut vm VM) !Value { return vm.throw_error(.type_error, 'WeakSet constructor requires new') },
		weak_set_construct, 0, PropertyName.from_str('WeakSet'))
	mut function := constructor.object
	realm.weak_set_constructor = function
	function.define_direct_property(PropertyName.from_str('prototype'), Value.from_object(prototype), 0)
	prototype.define_direct_property(PropertyName.from_str('constructor'), Value.from_object(function), attribute_writable | attribute_configurable)
	for name in ['add', 'delete', 'has'] {
		install_intrinsic_method(mut vm, realm, mut prototype, name, 1, fn [name] (mut vm VM) !Value {
			mut collection := weak_set_receiver(mut vm)!
			value := vm.argument(0)
			if name == 'add' {
				if !can_be_held_weakly(value) { return vm.throw_error_type(.type_error, .cannot_be_held_weakly, value.str()) }
				collection.add(value)!
				return vm.this_value()
			}
			return Value.from_bool(if name == 'has' { collection.has(value) } else { collection.remove(value) })
		})
	}
	prototype.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), Value.from_string(vm.create_string_from_str('WeakSet')), attribute_configurable)
}

fn weak_set_construct(mut vm VM, new_target &Object) !&Object {
	prototype := get_prototype_from_constructor(mut vm, new_target, fn (realm &Realm) &Object { return realm.weak_set_prototype or { panic('Missing WeakSet prototype') } })!
	object := create_weak_set(mut vm, prototype)!
	iterable := vm.argument(0)
	if iterable.is_nullish() { return object }
	adder := object.get(mut vm, PropertyName.from_str('add'))!
	if !adder.is_function() { return vm.throw_error_type(.type_error, .not_a_function, 'WeakSet add') }
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
