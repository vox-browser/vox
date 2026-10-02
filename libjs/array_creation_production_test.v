module libjs

// Run this file with -prod as well: every check is an ordinary statement so
// eliminating debug assertions cannot erase the operations or verification.
fn test_production_array_creation_preserves_sparse_length_and_list_elements() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	for length in [u64(0), 3, 0xffffffff] {
		array := ArrayObject.create(mut vm, vm.realm(), length, prototype)!
		mut object := array.object
		actual := object.get(mut vm, PropertyName.from_str('length'))!
		if array.length != u32(length) || actual.number != f64(length) {
			panic('ArrayCreate lost its sparse length in a production build')
		}
		if object.properties.len != 0 || voidptr(object.prototype?) != voidptr(prototype) {
			panic('ArrayCreate materialized holes or lost its supplied prototype')
		}
		descriptor := object.internal_get_own_property(PropertyName.from_str('length'))?
		if !descriptor.writable? || descriptor.enumerable? || descriptor.configurable? {
			panic('ArrayCreate did not initialize the source length descriptor')
		}
	}
	values := [Value.from_i32(17), js_undefined(), js_null(), Value.from_i32(42)]
	array := ArrayObject.create_from(mut vm, vm.realm(), values, prototype)!
	if array.length != 4 || array.object.own_property_keys().map(it.str()) != ['0', '1', '2', '3', 'length'] {
		panic('CreateArrayFromList omitted indexed properties')
	}
	actual_values := create_list_from_array_like(mut vm, Value.from_object(array.object), unsafe { nil })!
	if actual_values != values {
		panic('CreateArrayFromList lost explicit undefined/null values or ordering')
	}
}
