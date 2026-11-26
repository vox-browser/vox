// SPDX-License-Identifier: BSD-2-Clause
module libjs

// StringPrototype.cpp::replace_all. RegExp delegation preserves the original
// receiver; literal matching records non-overlapping UTF-16 positions before
// invoking replacement callbacks or substitutions.
fn string_prototype_replace_all(mut vm VM) !Value {
	receiver := require_object_coercible(mut vm, vm.this_value())!
	search_value := vm.argument(0)
	replace_value := vm.argument(1)
	if search_value.is_object() {
		object := search_value.as_object()
		if search_value.is_regexp(mut vm)! {
			flags := require_object_coercible(mut vm, object.get(mut vm, PropertyName.from_str('flags'))!)!
			if !flags.to_primitive_string(mut vm)!.utf16.data.contains(u16(`g`)) { return vm.throw_error(.type_error, 'String.replaceAll requires a global regular expression') }
		}
		method := object.get_method(mut vm, PropertyName.from_symbol(vm.well_known_symbol_replace()))!
		if !method.is_undefined() { return call(mut vm, method, search_value, [receiver, replace_value]) }
	}
	text := receiver.to_primitive_string(mut vm)!
	search := search_value.to_primitive_string(mut vm)!
	functional := replace_value.is_function()
	template := if functional { Utf16String.new() } else { replace_value.to_primitive_string(mut vm)!.utf16 }
	advance := if search.is_empty() { u64(1) } else { u64(search.utf16.len()) }
	mut positions := []uint{}
	mut from := u64(0)
	for from <= u64(text.utf16.len()) {
		vm.consume_execution_budget()!
		position := string_index_of(text.utf16, search.utf16, uint(from)) or { break }
		positions << position
		from = u64(position) + advance
	}
	if positions.len == 0 { return Value.from_string(text) }
	mut output := []u16{}
	mut previous := 0
	for position in positions {
		vm.consume_execution_budget()!
		replacement := if functional {
			call(mut vm, replace_value, js_undefined(), [Value.from_string(search), Value.from_f64(f64(position)), Value.from_string(text)])!.to_primitive_string(mut vm)!.utf16
		} else { get_substitution(mut vm, search.utf16, text.utf16, position, [], js_undefined(), template)! }
		prefix := text.utf16.data[previous..int(position)]
		length := checked_js_string_length_sum(mut vm, uint(output.len), uint(prefix.len), .string_size_must_not_overflow)!
		checked_js_string_length_sum(mut vm, length, uint(replacement.len()), .string_size_must_not_overflow)!
		output << prefix
		output << replacement.data
		previous = int(position) + search.utf16.len()
	}
	if previous < text.utf16.len() {
		tail := text.utf16.data[previous..]
		checked_js_string_length_sum(mut vm, uint(output.len), uint(tail.len), .string_size_must_not_overflow)!
		output << tail
	}
	return Value.from_string(vm.create_string(Utf16String{data: output}))
}
