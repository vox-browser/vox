module libjs

fn test_object_prototype_installs_source_metadata_and_immutable_root() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	prototype := ObjectPrototype.create(realm)
	prototype.initialize(mut vm, realm, PrimitiveObjectPrototypes{})
	mut object := prototype.object
	assert object.internal_get_prototype_of() == none
	assert object.internal_set_prototype_of(none)
	assert !object.internal_set_prototype_of(Object.create(realm, none))
	for name, length in {'hasOwnProperty': 1, 'toString': 0, 'toLocaleString': 0, 'valueOf': 0,
		'propertyIsEnumerable': 1, 'isPrototypeOf': 1, '__defineGetter__': 2,
		'__defineSetter__': 2, '__lookupGetter__': 1, '__lookupSetter__': 1} {
		property := object.internal_get_own_property(PropertyName.from_str(name))?
		assert property.writable? && property.configurable? && !property.enumerable?
		method := property.value?.as_object()
		assert method.get(mut vm, PropertyName.from_str('name'))!.as_string().utf16.str() == name
		assert method.get(mut vm, PropertyName.from_str('length'))!.number == length
		assert method.internal_get_prototype_of()? == realm.function_prototype_record()
	}
	to_string := object.get(mut vm, PropertyName.from_str('toString'))!
	assert call(mut vm, to_string, js_undefined(), []Value{})!.as_string().utf16.str() == '[object Undefined]'
	assert call(mut vm, to_string, js_null(), []Value{})!.as_string().utf16.str() == '[object Null]'
	mut receiver := Object.create(realm, object)
	receiver.class_name = 'NotATag'
	assert call(mut vm, to_string, Value.from_object(receiver), []Value{})!.as_string().utf16.str() == '[object Object]'
	receiver.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()),
		Value.from_string(vm.create_string_from_str('Custom')), 0)
	assert call(mut vm, to_string, Value.from_object(receiver), []Value{})!.as_string().utf16.str() == '[object Custom]'
}
