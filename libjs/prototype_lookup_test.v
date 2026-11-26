module libjs

struct PrototypeLookupHost {}

fn (_ &PrototypeLookupHost) get_own_property(key PropertyName) ?PropertyDescriptor {
	if !key.equals(PropertyName.from_str('x')) { return none }
	return PropertyDescriptor{ value: Value.from_i32(99), writable: true, enumerable: true, configurable: true }
}

fn (_ &PrototypeLookupHost) own_property_keys() []PropertyName {
	return [PropertyName.from_str('x')]
}

fn test_indexed_prototype_reads_keep_shadowing_mutation_prototype_and_host_hooks_live() {
	for enabled in [false, true] {
		set_indexed_prototype_lookups_for_testing(enabled)
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		mut upper := Object.create(vm.realm(), none)
		mut lower := Object.create(vm.realm(), upper)
		mut receiver := Object.create(vm.realm(), lower)
		assert upper.enable_indexed_properties() && lower.enable_indexed_properties()
		key := PropertyName.from_str('x')
		upper.define_direct_property(key, Value.from_i32(1), 7)
		vm.profile_native_code()!
		vm.diagnose_native_code(true)!
		for _ in 0 .. 4 {
			assert receiver.get(mut vm, key)!.number == 1
		}
		assert (vm.diagnose_native_code(false)!.indexed_prototype_lookup_hits > 0) == enabled
		upper.define_direct_property(key, Value.from_i32(2), 7)
		assert receiver.get(mut vm, key)!.number == 2
		lower.define_direct_property(key, Value.from_i32(3), 7)
		assert receiver.get(mut vm, key)!.number == 3
		assert lower.internal_delete(key)
		assert receiver.get(mut vm, key)!.number == 2
		receiver.define_direct_property(key, Value.from_i32(4), 7)
		assert receiver.get(mut vm, key)!.number == 4
		assert receiver.internal_delete(key)
		mut replacement := Object.create(vm.realm(), none)
		assert replacement.enable_indexed_properties()
		replacement.define_direct_property(key, Value.from_i32(5), 7)
		lower.prototype = replacement
		assert receiver.get(mut vm, key)!.number == 5
		lower.prototype = upper
		assert receiver.get(mut vm, key)!.number == 2
		assert upper.internal_delete(key)
		assert receiver.get(mut vm, key)!.is_undefined()
		upper.define_direct_property(key, Value.from_i32(6), 7)
		assert receiver.get(mut vm, key)!.number == 6
		upper.host_properties = HostProperties(&PrototypeLookupHost{})
		assert receiver.get(mut vm, key)!.number == 99
	}
	set_indexed_prototype_lookups_for_testing(true)
}

fn test_indexed_prototype_lookup_reads_current_accessor_and_keeps_original_receiver() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut holder := Object.create(vm.realm(), none)
	assert holder.enable_indexed_properties()
	mut receiver := Object.create(vm.realm(), holder)
	key := PropertyName.from_str('x')
	holder.define_direct_property(key, Value.from_i32(1), 7)
	for _ in 0 .. 3 {
		assert receiver.get(mut vm, key)!.number == 1
	}
	holder.define_native_accessor(mut vm, vm.realm(), key, fn [receiver] (mut vm VM) !Value {
		return Value.from_bool(voidptr(vm.this_value().as_object()) == voidptr(receiver))
	}, unsafe { nil }, 7, none)
	assert receiver.get(mut vm, key)!.as_bool()
}
