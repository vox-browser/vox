module libjs

// Runtime/StringConstructor.cpp::raw. Number/BigInt/String ToObject intrinsics
// are retained explicitly until their complete production graph is installed.
pub fn string_constructor_raw(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	template := vm.argument(0)
	substitution_count := if vm.argument_count() > 0 { vm.argument_count() - 1 } else { u32(0) }
	cooked := template.to_object_with_prototypes(mut vm, prototypes)!
	raw := cooked.get(mut vm, PropertyName.from_str('raw'))!
	literals := raw.to_object_with_prototypes(mut vm, prototypes)!
	literal_count := length_of_array_like(mut vm, literals)!
	if literal_count == 0 { return Value.from_string(vm.empty_string()) }
	mut units := []u16{}
	mut index := u64(0)
	for index < literal_count {
		// PropertyKey(size_t) keeps indices above the array-index range as strings.
		literal_value := literals.get(mut vm, PropertyName.from_str(index.str()))!
		literal := literal_value.to_primitive_string(mut vm)!
		units << literal.utf16.data
		if index + 1 == literal_count { break
		 }
		if index < u64(substitution_count) {
			substitution := vm.argument(u32(index + 1)).to_primitive_string(mut vm)!
			units << substitution.utf16.data
		}
		index++
	}
	return Value.from_string(vm.create_string(Utf16String{ data: units }))
}
