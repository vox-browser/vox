module libjs

fn lookup_test_object() (&VM, &Object) {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut object := Object.create(vm.realm(), none)
	for index in 0 .. 40 {
		object.define_direct_property(PropertyName.from_str('field${index}'), Value.from_i32(i32(index)), 7)
	}
	return vm, object
}

fn test_property_hints_observe_deletion_reinsertion_replacement_and_descriptors() {
	mut vm, mut object := lookup_test_object()
	key := PropertyName.from_str('field30')
	assert object.get(mut vm, key)!.number == 30
	assert object.property_lookup_hints != none
	assert object.internal_delete(PropertyName.from_str('field0'))
	assert object.get(mut vm, key)!.number == 30
	object.define_direct_property(key, Value.from_i32(80), 0)
	assert object.get(mut vm, key)!.number == 80
	assert !object.internal_delete(key)
	other := PropertyName.from_str('field20')
	assert object.get(mut vm, other)!.number == 20
	assert object.internal_delete(other)
	assert object.get(mut vm, other)!.is_undefined()
	object.define_direct_property(other, Value.from_i32(99), 7)
	assert object.get(mut vm, other)!.number == 99
	assert object.own_property_keys().last().equals(other)
}

fn test_property_hints_validate_collisions_and_live_public_storage() {
	mut vm, mut object := lookup_test_object()
	key := PropertyName.from_str('field30')
	assert object.get(mut vm, key)!.number == 30
	mut hints := object.property_lookup_hints or { panic('No hints') }
	hints.positions.set(property_lookup_hash(key), 2)
	assert object.get(mut vm, key)!.number == 30
	// Same-size external replacement/reordering cannot return stale values.
	object.properties.reverse_in_place()
	assert object.get(mut vm, key)!.number == 30
	index := object.find_own_property(key)
	object.properties[index].key = PropertyName.from_str('renamed')
	assert object.get(mut vm, key)!.is_undefined()
	assert object.get(mut vm, PropertyName.from_str('renamed'))!.number == 30
}

fn test_property_hints_distinguish_symbol_identity_indices_and_utf16_names() {
	mut vm, mut object := lookup_test_object()
	first := Symbol.create(utf16_string('same'), .unique)
	second := Symbol.create(utf16_string('same'), .unique)
	for index, key in [PropertyName.from_symbol(first), PropertyName.from_symbol(second),
		PropertyName.from_number(42), PropertyName.from_str('042'),
		PropertyName.from_utf16(utf16_string_from_code_units([u16(0xd800)])),
		PropertyName.from_utf16(utf16_string_from_code_units([u16(0xd801)]))] {
		object.define_direct_property(key, Value.from_i32(i32(index + 100)), 7)
		assert object.get(mut vm, key)!.number == index + 100
		assert object.get(mut vm, key)!.number == index + 100
	}
}

fn test_property_hints_keep_misses_prototypes_accessors_and_bounded_storage_live() {
	mut vm, mut object := lookup_test_object()
	mut prototype := Object.create(vm.realm(), none)
	object.prototype = prototype
	key := PropertyName.from_str('later')
	assert object.get(mut vm, key)!.is_undefined()
	prototype.define_direct_property(key, Value.from_i32(7), 7)
	assert object.get(mut vm, key)!.number == 7
	object.define_native_accessor(mut vm, vm.realm(), key, fn (mut vm VM) !Value {
		return Value.from_i32(9)
	}, unsafe { nil }, 7, none)
	assert object.get(mut vm, key)!.number == 9
	assert object.internal_delete(key)
	assert object.get(mut vm, key)!.number == 7
	for index in 0 .. 200 {
		name := PropertyName.from_str('churn${index}')
		object.define_direct_property(name, Value.from_i32(1), 7)
		assert object.get(mut vm, name)!.number == 1
		assert object.internal_delete(name)
	}
	hints := object.property_lookup_hints or { panic('No hints') }
	assert hints.positions.count <= property_lookup_hint_limit
	mut small := Object.create(vm.realm(), none)
	small.define_direct_property(key, Value.from_i32(1), 7)
	assert small.get(mut vm, key)!.number == 1
	assert small.property_lookup_hints == none
}

fn test_property_hint_control_and_diagnostic_do_not_change_values() {
	mut vm, mut object := lookup_test_object()
	key := PropertyName.from_str('field30')
	set_property_lookup_hints_for_testing(false)
	defer { set_property_lookup_hints_for_testing(true) }
	assert object.get(mut vm, key)!.number == 30
	assert object.property_lookup_hints == none
	set_property_lookup_hints_for_testing(true)
	diagnose_property_lookup_hints_for_testing(true)
	assert object.get(mut vm, key)!.number == 30
	assert object.get(mut vm, key)!.number == 30
	activity := diagnose_property_lookup_hints_for_testing(false)
	assert activity.hits > 0 && activity.misses > 0
	assert diagnose_property_lookup_hints_for_testing(false).hits == 0
}
