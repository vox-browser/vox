// SPDX-License-Identifier: BSD-2-Clause
module libjs

@[heap]
struct LegacyNamedFixture {
mut:
	names []Utf16String
	values []Value
	reads int
	checks int
}

fn (fixture &LegacyNamedFixture) is_supported_property_name(name Utf16String) bool {
	mut owner := unsafe { &LegacyNamedFixture(fixture) }; owner.checks++
	return fixture.names.any(it == name)
}

fn (fixture &LegacyNamedFixture) named_property_value(name Utf16String) Value {
	mut owner := unsafe { &LegacyNamedFixture(fixture) }; owner.reads++
	for index, key in fixture.names { if key == name { return fixture.values[index] } }
	return js_null()
}

fn (fixture &LegacyNamedFixture) supported_property_names() []Utf16String { return fixture.names.clone() }
fn (_ &LegacyNamedFixture) is_supported_property_index(index u32) bool { return index == 0 }
fn (_ &LegacyNamedFixture) get_own_property(key PropertyName) ?PropertyDescriptor {
	if !key.is_number() || key.number != 0 { return none }
	return PropertyDescriptor{value: Value.from_i32(100), writable: false, enumerable: true, configurable: true}
}
fn (_ &LegacyNamedFixture) own_property_keys() []PropertyName { return [PropertyName.from_number(0)] }

fn named_protocol_fixture(mut vm VM, overrides bool) (&Object, &LegacyNamedFixture) {
	mut object := Object.create(vm.realm(), none)
	fixture := &LegacyNamedFixture{names: [utf16_string('field')], values: [Value.from_i32(42)]}
	object.legacy_platform_object = LegacyPlatformObject{named_properties: LegacyNamedProperties(fixture), legacy_override_builtins: overrides, legacy_unenumerable_named_properties: true}
	mut global := vm.global_object()
	global.define_direct_property(PropertyName.from_str('target'), Value.from_object(object), attribute_writable | attribute_configurable)
	return object, fixture
}

fn named_protocol_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'legacy-named.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})
}

fn test_legacy_named_getters_are_live_readonly_unenumerable_and_configurable() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	object, mut fixture := named_protocol_fixture(mut vm, false)
	key := PropertyName.from_str('field')
	assert object.get(mut vm, key)!.number == 42 && fixture.reads == 1
	fixture.values[0] = Value.from_i32(43)
	assert object.get(mut vm, key)!.number == 43 && fixture.reads == 2
	descriptor := object.get_own_property_checked(mut vm, key)!.descriptor or { panic('Missing name') }
	assert descriptor.writable == false && descriptor.enumerable == false && descriptor.configurable == true
	assert object.has_property_checked(mut vm, key)! && object.has_own_property_checked(mut vm, key)!
}

fn test_legacy_named_prototype_visibility_and_override_flag_follow_webidl() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	mut object, _ := named_protocol_fixture(mut vm, false)
	mut prototype := Object.create(vm.realm(), none)
	key := PropertyName.from_str('field')
	prototype.define_direct_property(key, Value.from_i32(7), attribute_configurable)
	assert object.internal_set_prototype_of(prototype)
	assert object.get(mut vm, key)!.number == 7
	assert !object.has_own_property_checked(mut vm, key)!
	assert !object.internal_define_own_property(mut vm, key, PropertyDescriptor{value: Value.from_i32(8)})!
	assert object.delete_checked(mut vm, key)!
	assert prototype.internal_delete(key)
	assert object.get(mut vm, key)!.number == 42 && !object.delete_checked(mut vm, key)!
	mut overriding, _ := named_protocol_fixture(mut vm, true)
	prototype.define_direct_property(key, Value.from_i32(7), attribute_configurable)
	assert overriding.internal_set_prototype_of(prototype)
	assert overriding.get(mut vm, key)!.number == 42
}

fn test_legacy_named_ordinary_own_storage_hides_native_names_until_deleted() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	mut object, _ := named_protocol_fixture(mut vm, false)
	key := PropertyName.from_str('field')
	object.define_direct_property(key, Value.from_i32(9), attribute_writable | attribute_configurable)
	assert object.get(mut vm, key)!.number == 9
	assert object.internal_define_own_property(mut vm, key, PropertyDescriptor{value: Value.from_i32(10)})!
	assert object.delete_checked(mut vm, key)!
	assert object.get(mut vm, key)!.number == 42
}

fn test_legacy_named_visibility_observes_proxy_own_property_and_prototype_traps() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	named_protocol_fixture(mut vm, false)
	assert named_protocol_eval(mut vm, 'var seen="",p=new Proxy({}, {getOwnPropertyDescriptor(t,k){seen+="own:"+k+";";return undefined},getPrototypeOf(){seen+="proto;";return null}});Object.setPrototypeOf(target,p);target.field===42&&seen==="own:field;proto;"')!.as_bool()
	assert named_protocol_eval(mut vm, 'var marker={},same=false;Object.setPrototypeOf(target,new Proxy({}, {getOwnPropertyDescriptor(){throw marker}}));try{Reflect.ownKeys(target)}catch(e){same=e===marker}same')!.as_bool()
}

fn test_legacy_named_set_ignores_named_getter_and_preserves_prototype_setters() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	named_protocol_fixture(mut vm, true)
	assert named_protocol_eval(mut vm, 'var assigned=0;Object.setPrototypeOf(target,{set field(v){assigned=v;this.seen=v}});target.field=7;var other={};Reflect.set(target,"field",8,other)&&target.field===42&&target.seen===7&&other.seen===8&&assigned===8')!.as_bool()
}

fn test_legacy_named_utf16_identity_symbols_and_missing_indices_remain_distinct() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	mut object, mut fixture := named_protocol_fixture(mut vm, false)
	lone := Utf16String{data: [u16(0xd800)]}
	fixture.names = [lone, utf16_string('1')]; fixture.values = [Value.from_i32(11), Value.from_i32(12)]
	assert object.get(mut vm, PropertyName.from_utf16(lone))!.number == 11
	checks := fixture.checks
	assert object.get(mut vm, PropertyName.from_symbol(Symbol.create(utf16_string('x'), .unique)))!.is_undefined()
	assert fixture.checks == checks
	metadata := object.legacy_platform_object or { panic('Missing metadata') }
	object.host_properties = HostProperties(fixture)
	object.legacy_platform_object = LegacyPlatformObject{...metadata, indexed_properties: LegacyIndexedProperties(fixture)}
	assert object.get(mut vm, PropertyName.from_number(0))!.number == 100
	assert object.get(mut vm, PropertyName.from_number(1))!.is_undefined()
}

fn test_legacy_named_keys_order_native_names_before_owned_strings_and_symbols() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	mut object, _ := named_protocol_fixture(mut vm, false)
	object.define_direct_property(PropertyName.from_symbol(Symbol.create(utf16_string('extra'), .unique)), Value.from_i32(1), attribute_configurable)
	object.define_direct_property(PropertyName.from_str('own'), Value.from_i32(2), attribute_configurable)
	keys := object.own_property_keys_checked(mut vm)!
	assert keys.len == 3 && keys[0].str() == 'field' && keys[1].str() == 'own' && keys[2].is_symbol()
}

fn test_legacy_named_properties_object_is_skipped_during_prototype_visibility() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	mut object, _ := named_protocol_fixture(mut vm, false)
	mut prototype := Object.create(vm.realm(), none)
	prototype.define_direct_property(PropertyName.from_str('field'), Value.from_i32(7), attribute_configurable)
	prototype.legacy_platform_object = LegacyPlatformObject{is_named_properties_object: true}
	assert object.internal_set_prototype_of(prototype)
	assert object.get(mut vm, PropertyName.from_str('field'))!.number == 42
	prototype.legacy_platform_object = none
	assert object.get(mut vm, PropertyName.from_str('field'))!.number == 7
}
