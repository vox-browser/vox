module libjs

fn test_reflect_object_initialization_retains_all_thirteen_method_descriptors_and_source_order() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	parent := Object.create(realm, none)
	array_parent := Object.create(realm, parent)
	reflect := ReflectObject.create(mut vm, realm, parent, array_parent).object
	assert voidptr(reflect.prototype?) == voidptr(parent)
	assert !Value.from_object(reflect).is_function() && !Value.from_object(reflect).is_constructor()
	names := ['apply', 'construct', 'defineProperty', 'deleteProperty', 'get',
		'getOwnPropertyDescriptor', 'getPrototypeOf', 'has', 'isExtensible', 'ownKeys',
		'preventExtensions', 'set', 'setPrototypeOf']
	lengths := [3, 2, 3, 2, 2, 2, 1, 2, 1, 1, 1, 3, 2]
	keys := reflect.own_property_keys()
	assert keys.len == 14
	for index, name in names {
		assert keys[index].str() == name
		descriptor := reflect.internal_get_own_property(keys[index])?
		assert descriptor.writable? && descriptor.configurable? && !descriptor.enumerable?
		function := descriptor.value?.as_object()
		assert voidptr(function.prototype?) == voidptr(realm.function_prototype_record())
		assert Value.from_object(function).is_function()
			&& !Value.from_object(function).is_constructor()
		assert function.get(mut vm, PropertyName.from_str('name'))!.as_string().str() == name
		assert function.get(mut vm, PropertyName.from_str('length'))!.number == lengths[index]
		assert function.native_initial_name?.str() == name
		for property in ['name', 'length'] {
			metadata := function.internal_get_own_property(PropertyName.from_str(property))?
			assert !metadata.writable? && !metadata.enumerable? && metadata.configurable?
		}
	}
	tag := keys.last()
	assert tag.is_symbol()
		&& voidptr(tag.as_symbol()) == voidptr(vm.well_known_symbol_to_string_tag())
	descriptor := reflect.internal_get_own_property(tag)?
	assert descriptor.value?.as_string().str() == 'Reflect'
	assert descriptor.configurable? && !descriptor.writable? && !descriptor.enumerable?
}

fn test_reflect_descriptor_and_key_arrays_use_native_callee_realm_prototypes_after_borrowing() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	local := vm.realm()
	foreign := create_simple_execution_context(mut vm).realm?
	vm.pop_execution_context()
	parent := Object.create(foreign, none)
	array_parent := Object.create(foreign, parent)
	reflect := ReflectObject.create(mut vm, foreign, parent, array_parent).object
	mut target := Object.create(local, none)
	target.define_direct_property(PropertyName.from_str('answer'), Value.from_i32(42), 7)
	get_descriptor := reflect.get(mut vm, PropertyName.from_str('getOwnPropertyDescriptor'))!
	result := call(mut vm, get_descriptor, js_null(), [Value.from_object(target),
		Value.from_string(vm.create_string_from_str('answer'))])!.as_object()
	assert voidptr(result.prototype?) == voidptr(parent)
	assert result.get(mut vm, PropertyName.from_str('value'))!.number == 42
	get_keys := reflect.get(mut vm, PropertyName.from_str('ownKeys'))!
	keys := call(mut vm, get_keys, Value.from_i32(42), [Value.from_object(target)])!.as_object().array_object?
	assert voidptr(keys.realm) == voidptr(foreign)
		&& voidptr(keys.object.prototype?) == voidptr(array_parent)
	assert keys.object.get(mut vm, PropertyName.from_number(0))!.as_string().str() == 'answer'
	assert vm.running_execution_context() == base && voidptr(vm.realm()) == voidptr(local)
	assert vm.interpreter_stack().depth() == 0
}
