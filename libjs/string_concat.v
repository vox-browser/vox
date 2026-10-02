module libjs

// PrimitiveString.cpp::create(VM&, lhs, rhs), with the existing flattened
// representation in place of the untranslated rope/short-flat storage branches.
// Empty operands keep the source's cell-identity fast paths.
fn concatenate_primitive_strings(mut vm VM, lhs &PrimitiveString, rhs &PrimitiveString) &PrimitiveString {
	if lhs.is_empty() && rhs.is_empty() { return vm.empty_string() }
	if lhs.is_empty() { return rhs }
	if rhs.is_empty() { return lhs }
	mut units := lhs.utf16.data.clone()
	units << rhs.utf16.data
	return vm.create_string(Utf16String{ data: units })
}

// Runtime/StringPrototype.cpp::concat. Each conversion and concatenation
// completes before visiting the next argument.
pub fn string_prototype_concat(mut vm VM) !Value {
	mut result := string_primitive_from(mut vm)!
	for index in 0 .. vm.argument_count() {
		next := vm.argument(index).to_primitive_string(mut vm)!
		result = concatenate_primitive_strings(mut vm, result, next)
	}
	return Value.from_string(result)
}
