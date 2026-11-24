module libjs

// Object.create() allocates a zeroed record and sets the non-zero defaults;
// it must equal the struct literal's defaults in every other byte.
fn test_object_create_matches_struct_literal_defaults() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	prototype := vm.realm().object_prototype_record()
	created := Object.create(vm.realm(), prototype)
	reference := Object{
		prototype: prototype
	}
	assert created.extensible == reference.extensible && created.class_name == reference.class_name
	assert created.properties.len == 0 && created.private_elements.len == 0
	mut copy := *created
	// Equal but separately allocated: compare every other byte.
	copy.properties = reference.properties
	copy.private_elements = reference.private_elements
	copy.class_name = reference.class_name
	assert unsafe { vmemcmp(&copy, &reference, int(sizeof(Object))) } == 0
	mut object := Object.create(vm.realm(), none)
	assert object.prototype == none
	object.properties << OwnProperty{key: PropertyName.from_str('a'), value: Value.from_i32(1)}
	assert object.properties.len == 1 && object.properties[0].value.number == 1
}
