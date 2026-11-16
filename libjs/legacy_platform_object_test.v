// SPDX-License-Identifier: BSD-2-Clause
module libjs

@[heap]
struct LegacyIndexedFixture {
mut:
	values []Value
	writes []u32
}

fn (fixture &LegacyIndexedFixture) get_own_property(key PropertyName) ?PropertyDescriptor {
	if !key.is_number() || int(key.number) >= fixture.values.len { return none }
	return PropertyDescriptor{value: fixture.values[key.number], writable: false, enumerable: true, configurable: false}
}

fn (fixture &LegacyIndexedFixture) own_property_keys() []PropertyName {
	return []PropertyName{len: fixture.values.len, init: PropertyName.from_number(u32(index))}
}

fn (fixture &LegacyIndexedFixture) is_supported_property_index(index u32) bool {
	return int(index) < fixture.values.len
}

fn (fixture &LegacyIndexedFixture) set_indexed_property(mut vm VM, index u32, value Value) ! {
	if value.is_string() && value.as_string().str() == 'throw' { return throw_completion(value) }
	mut owner := unsafe { &LegacyIndexedFixture(fixture) }
	owner.writes << index
	for owner.values.len <= int(index) { owner.values << js_undefined() }
	owner.values[index] = value
}

fn legacy_indexed_fixture(mut vm VM, writable bool) (&Object, &LegacyIndexedFixture) {
	mut object := Object.create(vm.realm(), vm.realm().object_prototype)
	owner := &LegacyIndexedFixture{values: [Value.from_i32(10)]}
	object.host_properties = HostProperties(owner)
	object.legacy_platform_object = LegacyPlatformObject{
		indexed_properties: LegacyIndexedProperties(owner)
		indexed_setter: if writable { ?LegacyIndexedPropertySetter(LegacyIndexedPropertySetter(owner)) } else { none }
	}
	return object, owner
}

fn test_readonly_legacy_indices_are_configurable_but_cannot_be_deleted_or_defined() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	mut object, owner := legacy_indexed_fixture(mut vm, false)
	key := PropertyName.from_number(0)
	descriptor := object.get_own_property_checked(mut vm, key)!.descriptor or { panic('Missing index') }
	assert descriptor.configurable == true && descriptor.enumerable == true && descriptor.writable == false
	assert !object.internal_delete(key) && object.internal_delete(PropertyName.from_number(3))
	assert !object.internal_define_own_property(mut vm, key, PropertyDescriptor{value: Value.from_i32(20)})!
	assert !object.internal_define_own_property(mut vm, PropertyName.from_number(3), PropertyDescriptor{value: Value.from_i32(20)})!
	assert !object.internal_set(mut vm, key, Value.from_i32(20), Value.from_object(object))!
	assert owner.values[0].number == 10 && owner.writes.len == 0
}

fn test_writable_legacy_indices_use_native_setter_before_prototype_properties() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	mut object, owner := legacy_indexed_fixture(mut vm, true)
	mut parent := Object.create(vm.realm(), none)
	parent.define_direct_property(PropertyName.from_number(2), Value.from_i32(99), 0)
	assert object.internal_set_prototype_of(parent)
	assert object.internal_set(mut vm, PropertyName.from_number(2), Value.from_i32(42), Value.from_object(object))!
	assert owner.values.len == 3 && owner.values[2].number == 42 && owner.writes == [u32(2)]
	descriptor := object.internal_get_own_property(PropertyName.from_number(2)) or { panic('Missing native index') }
	assert descriptor.writable == true && descriptor.configurable == true
	assert !object.internal_define_own_property(mut vm, PropertyName.from_number(0), PropertyDescriptor{getter: js_undefined()})!
	assert owner.writes.len == 1
	assert object.internal_define_own_property(mut vm, PropertyName.from_number(0), PropertyDescriptor{writable: true})!
	assert owner.values[0].is_undefined()
}

fn test_legacy_index_assignment_respects_distinct_receiver_and_preserves_native_throw() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	mut object, owner := legacy_indexed_fixture(mut vm, true)
	mut receiver := Object.create(vm.realm(), none)
	key := PropertyName.from_number(0)
	assert object.internal_set(mut vm, key, Value.from_i32(22), Value.from_object(receiver))!
	assert receiver.get(mut vm, key)!.number == 22 && owner.values[0].number == 10 && owner.writes.len == 0
	marker := Value.from_string(vm.create_string_from_str('throw'))
	if _ := object.internal_set(mut vm, key, marker, Value.from_object(object)) { assert false }
	else { assert is_throw_completion(err) && same_value(thrown_value(err), marker) }
	assert owner.writes.len == 0
}

fn test_legacy_platform_objects_stay_extensible_and_keep_nonindex_expandos_ordinary() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	mut object, _ := legacy_indexed_fixture(mut vm, false)
	assert !object.internal_prevent_extensions() && object.internal_is_extensible()
	for name in ['01', '-1', '4294967295', 'extra'] {
		key := PropertyName.from_str(name)
		assert object.create_data_property(mut vm, key, Value.from_i32(7))!
		assert object.get(mut vm, key)!.number == 7 && object.internal_delete(key)
	}
	mut ordinary := Object.create(vm.realm(), none)
	ordinary.host_properties = object.host_properties
	assert ordinary.internal_prevent_extensions() && !ordinary.internal_is_extensible()
	descriptor := ordinary.internal_get_own_property(PropertyName.from_number(0)) or { panic('Missing native property') }
	assert descriptor.configurable == false
}
