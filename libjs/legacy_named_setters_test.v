// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn (fixture &LegacyNamedFixture) set_named_property(mut vm VM, name Utf16String, value Value) ! {
	if name == utf16_string('fail') { return vm.throw_error(.type_error, 'native setter failed') }
	mut owner := unsafe { &LegacyNamedFixture(fixture) }
	for index, key in fixture.names {
		if key == name {
			owner.values[index] = value
			return
		}
	}
	owner.names << name
	owner.values << value
}

fn (fixture &LegacyNamedFixture) delete_named_property(mut vm VM, name Utf16String) !bool {
	if name == utf16_string('fail') { return vm.throw_error(.type_error, 'native deleter failed') }
	mut owner := unsafe { &LegacyNamedFixture(fixture) }
	for index, key in fixture.names {
		if key == name {
			owner.names.delete(index)
			owner.values.delete(index)
			break
		}
	}
	return true
}

fn writable_named_fixture(mut vm VM, overrides bool) &LegacyNamedFixture {
	mut object, fixture := named_protocol_fixture(mut vm, overrides)
	metadata := object.legacy_platform_object or { panic('Missing metadata') }
	object.legacy_platform_object = LegacyPlatformObject{
		...metadata
		named_setter:                         LegacyNamedPropertySetter(fixture)
		named_deleter:                        LegacyNamedPropertyDeleter(fixture)
		legacy_unenumerable_named_properties: false
	}
	return fixture
}

fn test_legacy_named_setters_create_update_define_and_delete_live_native_names() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	writable_named_fixture(mut vm, true)
	assert named_protocol_eval(mut vm, 'target.field=9;target.fresh=10;target[0]=11;var d=Object.getOwnPropertyDescriptor(target,"field");var before=target.field===9&&target.fresh===10&&target[0]===11&&d.writable&&d.enumerable&&d.configurable;Object.defineProperty(target,"fresh",{value:12,writable:false,configurable:false});var defined=target.fresh===12&&Object.getOwnPropertyDescriptor(target,"fresh").configurable;delete target.field;before&&defined&&!("field" in target)&&delete target.absent')!.as_bool()
	assert named_protocol_eval(mut vm, 'var a=Reflect.defineProperty(target,"accessor",{get(){return 1}}),b=Reflect.defineProperty(target,"generic",{enumerable:true});!a&&!b&&!("accessor" in target)&&!("generic" in target)')!.as_bool()
}

fn test_legacy_named_setters_preserve_distinct_receiver_symbols_and_ordinary_own_definitions() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	writable_named_fixture(mut vm, false)
	assert named_protocol_eval(mut vm, 'var other={},s=Symbol("own");target[s]=7;var set=Reflect.set(target,"field",8,other);Object.defineProperty(target,"ordinary",{value:1,writable:true,configurable:true});set&&other.field===8&&target.field===42&&target[s]===7&&target.ordinary===1')!.as_bool()
}

fn test_legacy_named_setter_and_deleter_abrupt_completions_reach_author_code() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut fixture := writable_named_fixture(mut vm, true)
	assert named_protocol_eval(mut vm, 'var n=0;try{target.fail=1}catch(e){if(e instanceof TypeError&&e.message==="native setter failed")n++}try{Object.defineProperty(target,"fail",{value:1})}catch(e){if(e instanceof TypeError)n++}n===2')!.as_bool()
	fixture.names << utf16_string('fail')
	fixture.values << Value.from_i32(1)
	assert named_protocol_eval(mut vm, 'var caught=false;try{delete target.fail}catch(e){caught=e instanceof TypeError&&e.message==="native deleter failed"}caught&&target.fail===1')!.as_bool()
}
