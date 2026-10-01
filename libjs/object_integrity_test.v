module libjs

fn test_ordinary_set_prototype_rejects_cycles_and_respects_extensibility() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut root := Object.create(vm.realm(), none)
	mut parent := Object.create(vm.realm(), root)
	mut child := Object.create(vm.realm(), parent)
	assert child.internal_get_prototype_of()? == parent
	assert !root.internal_set_prototype_of(child)
	assert !parent.internal_set_prototype_of(child)
	assert !child.internal_set_prototype_of(child)
	assert root.internal_get_prototype_of() == none
	assert parent.internal_get_prototype_of()? == root
	assert child.internal_get_prototype_of()? == parent
	assert child.internal_prevent_extensions()
	assert !child.internal_is_extensible()
	// The existing prototype is accepted before checking extensibility.
	assert child.internal_set_prototype_of(parent)
	assert !child.internal_set_prototype_of(root)
	assert !child.internal_set_prototype_of(none)
	assert root.internal_set_prototype_of(none)
	assert parent.internal_set_prototype_of(none)
	assert parent.internal_get_prototype_of() == none
	assert parent.internal_prevent_extensions()
	assert parent.internal_set_prototype_of(none)
	assert !parent.internal_set_prototype_of(root)
}

fn test_ordinary_prototype_replacement_refreshes_lookup_and_receiver_writes() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut first := Object.create(vm.realm(), none)
	mut second := Object.create(vm.realm(), none)
	first.create_data_property(mut vm, PropertyName.from_str('answer'), Value.from_i32(17)) or {
		panic(err)
	}
	second.create_data_property(mut vm, PropertyName.from_str('answer'), Value.from_i32(42)) or {
		panic(err)
	}
	second.define_direct_property(PropertyName.from_str('fixed'), Value.from_i32(2), 0)
	mut object := Object.create(vm.realm(), first)
	assert object.get(mut vm, PropertyName.from_str('answer'))!.number == 17
	assert object.internal_set_prototype_of(second)
	assert object.get(mut vm, PropertyName.from_str('answer'))!.number == 42
	assert !object.internal_set(mut vm, PropertyName.from_str('fixed'), Value.from_i32(9),
		Value.from_object(object))!
	assert object.internal_set(mut vm, PropertyName.from_str('answer'), Value.from_i32(9),
		Value.from_object(object))!
	assert object.get(mut vm, PropertyName.from_str('answer'))!.number == 9
	assert second.get(mut vm, PropertyName.from_str('answer'))!.number == 42
}

fn test_sealing_and_freezing_follow_ordinary_own_property_keys_and_descriptors() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for level in [IntegrityLevel.sealed, .frozen] {
		mut object := Object.create(vm.realm(), none)
		symbol := Symbol.create(utf16_string('public'), .unique)
		private := Symbol.create(utf16_string('private'), .private)
		keys := [PropertyName.from_str('answer'), PropertyName.from_number(3),
			PropertyName.from_symbol(symbol)]
		for key in keys {
			object.create_data_property(mut vm, key, Value.from_i32(42)) or { panic(err) }
		}
		object.create_data_property(mut vm, PropertyName.from_symbol(private), Value.from_i32(17)) or {
			panic(err)
		}
		assert !object.test_integrity_level(.sealed)
		assert !object.test_integrity_level(.frozen)
		assert object.set_integrity_level(mut vm, level)!
		assert !object.internal_is_extensible()
		assert object.test_integrity_level(.sealed)
		assert object.test_integrity_level(.frozen) == (level == .frozen)
		assert !object.create_data_property(mut vm, PropertyName.from_str('missing'),
			Value.from_i32(9)) or { panic(err) }
		for key in keys {
			descriptor := object.internal_get_own_property(key)?
			assert !descriptor.configurable? && descriptor.enumerable?
			assert descriptor.writable? == (level == .sealed)
			assert !object.internal_delete(key)
			assert object.internal_set(mut vm, key, Value.from_i32(9), Value.from_object(object))! == (level == .sealed)
		}
		// Private symbols are excluded by OrdinaryOwnPropertyKeys, so the
		// private slot remains writable/configurable after public freezing.
		private_descriptor := object.internal_get_own_property(PropertyName.from_symbol(private))?
		assert private_descriptor.configurable? && private_descriptor.writable?
		assert object.set_integrity_level(mut vm, .frozen)!
		assert object.test_integrity_level(.frozen)
	}
}

fn test_empty_nonextensible_objects_are_both_sealed_and_frozen() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut object := Object.create(vm.realm(), none)
	assert !object.test_integrity_level(.sealed)
	assert object.internal_prevent_extensions()
	assert object.test_integrity_level(.sealed)
	assert object.test_integrity_level(.frozen)
	assert object.set_integrity_level(mut vm, .frozen)!
}
