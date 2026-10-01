module libjs

import math

fn test_number_wrapper_preserves_numeric_payload_brand_and_explicit_prototype() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut parent := Object.create(vm.realm(), none)
	parent.define_direct_property(PropertyName.from_str('inherited'), Value.from_i32(42), 7)
	for value in [0.0, -0.0, 42.5, math.inf(-1), math.inf(1),
		math.nan()] {
		wrapper := NumberObject.create(vm.realm(), value, parent)
		assert same_value(Value.from_f64(wrapper.value), Value.from_f64(value))
		assert voidptr(wrapper.object.number_object?) == voidptr(wrapper)
		assert wrapper.object.class_name == 'NumberObject' && wrapper.object.properties.len == 0
		assert voidptr(wrapper.object.prototype?) == voidptr(parent)
		assert wrapper.object.get(mut vm, PropertyName.from_str('inherited'))!.number == 42
		assert wrapper.object.boolean_object == none && wrapper.object.bigint_object == none
	}
}

fn test_number_wrapper_allocations_have_independent_ordinary_properties() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	a := NumberObject.create(vm.realm(), 42, parent)
	b := NumberObject.create(vm.realm(), 42, parent)
	assert voidptr(a) != voidptr(b) && voidptr(a.object) != voidptr(b.object)
	mut object := a.object
	assert object.create_data_property(mut vm, PropertyName.from_str('extra'), Value.from_i32(17))!
	assert b.object.get(mut vm, PropertyName.from_str('extra'))!.is_undefined()
	assert a.value == 42 && b.value == 42
}
