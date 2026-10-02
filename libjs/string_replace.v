module libjs

// Runtime/StringPrototype.cpp::replace. @@replace dispatch uses the ordinary
// translated call path; RegExp's native specialization remains its dependency.
pub fn string_prototype_replace(mut vm VM) !Value {
	search_value := vm.argument(0)
	replace_value := vm.argument(1)
	receiver := require_object_coercible(mut vm, vm.this_value())!
	if search_value.is_object() {
		replacer := search_value.as_object().get_method(mut vm,
			PropertyName.from_symbol(vm.well_known_symbol_replace()))!
		if !replacer.is_undefined() {
			return call(mut vm, replacer, search_value, [receiver, replace_value])
		}
	}
	text := receiver.to_primitive_string(mut vm)!
	search := search_value.to_primitive_string(mut vm)!
	mut replace_string := ?Utf16String(none)
	if !replace_value.is_function() {
		replace_string = replace_value.to_primitive_string(mut vm)!.utf16
	}
	position := string_index_of(text.utf16, search.utf16, 0) or { return Value.from_string(text) }
	preceding := text.utf16.data[..int(position)]
	following := text.utf16.data[int(position) + search.utf16.len()..]
	replacement := if replace_value.is_function() {
		result := call(mut vm, replace_value, js_undefined(), [
			Value.from_string(search),
			Value.from_f64(f64(position)),
			Value.from_string(text),
		])!
		result.to_primitive_string(mut vm)!.utf16
	} else {
		template := replace_string or { panic('Replacement template must be a String') }
		get_substitution(mut vm, search.utf16, text.utf16, position, []Value{}, js_undefined(),
			template)!
	}
	mut builder := []u16{}
	builder << preceding
	builder << replacement.data
	builder << following
	return Value.from_string(vm.create_string(Utf16String{ data: builder }))
}
