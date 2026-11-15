// SPDX-License-Identifier: BSD-2-Clause
module libjs

import math

// RegExpPrototype.cpp::symbol_replace's generic algorithm. Keep RegExpExec,
// getters, replacement callbacks and substitutions observable; do not bypass
// them with a host regex/string replacement or a builtin-only shortcut.
fn regexp_symbol_replace(mut vm VM) !Value {
	if !vm.this_value().is_object() { return vm.throw_error(.type_error, 'RegExp replace requires an object') }
	mut object := vm.this_value().as_object()
	text := vm.argument(0).to_primitive_string(mut vm)!
	replacer := vm.argument(1)
	functional := replacer.is_function()
	template := if functional { Utf16String.new() } else { replacer.to_primitive_string(mut vm)!.utf16 }
	flags := object.get(mut vm, PropertyName.from_str('flags'))!.to_primitive_string(mut vm)!.utf16
	global := flags.data.contains(u16(`g`))
	unicode := flags.data.contains(u16(`u`)) || flags.data.contains(u16(`v`))
	if global { object.set(mut vm, PropertyName.from_str('lastIndex'), Value.from_i32(0), .yes)! }
	mut results := []&Object{}
	for {
		vm.consume_execution_budget()!
		result := regexp_exec(mut vm, object, text)!
		if result.is_null() { break }
		results << result.as_object()
		if !global { break }
		matched := result.as_object().get(mut vm, PropertyName.from_number(0))!.to_primitive_string(mut vm)!
		if matched.is_empty() {
			index := object.get(mut vm, PropertyName.from_str('lastIndex'))!.to_length(mut vm)!
			next := if unicode && index < u64(text.utf16.len()) { index + u64(string_code_point_at(text.utf16, int(index)).code_unit_count) } else { index + 1 }
			object.set(mut vm, PropertyName.from_str('lastIndex'), Value.from_f64(f64(next)), .yes)!
		}
	}
	mut output := []u16{}
	mut next_source := u64(0)
	for result in results {
		vm.consume_execution_budget()!
		length := length_of_array_like(mut vm, result)!
		count := if length == 0 { u64(0) } else { length - 1 }
		matched := result.get(mut vm, PropertyName.from_number(0))!.to_primitive_string(mut vm)!
		position := uint(math.min(math.max(result.get(mut vm, PropertyName.from_str('index'))!.to_integer_or_infinity(mut vm)!, 0), f64(text.utf16.len())))
		mut captures := []Value{}
		for index := u64(1); index <= count; index++ {
			vm.consume_execution_budget()!
			capture := result.get(mut vm, PropertyName.from_str(index.str()))!
			captures << if capture.is_undefined() { capture } else { Value.from_string(capture.to_primitive_string(mut vm)!) }
		}
		mut named := result.get(mut vm, PropertyName.from_str('groups'))!
		replacement := if functional {
			mut args := [Value.from_string(matched)]
			args << captures
			args << Value.from_f64(f64(position))
			args << Value.from_string(text)
			if !named.is_undefined() { args << named }
			call(mut vm, replacer, js_undefined(), args)!.to_primitive_string(mut vm)!.utf16
		} else {
			if !named.is_undefined() { named = Value.from_object(named.to_object_with_prototypes(mut vm, realm_primitive_prototypes())!) }
			get_substitution(mut vm, matched.utf16, text.utf16, position, captures, named, template)!
		}
		if u64(position) >= next_source {
			prefix := text.utf16.data[int(next_source)..int(position)]
			combined := checked_js_string_length_sum(mut vm, uint(output.len), uint(prefix.len), .string_size_must_not_overflow)!
			checked_js_string_length_sum(mut vm, combined, uint(replacement.len()), .string_size_must_not_overflow)!
			output << prefix
			output << replacement.data
			next_source = u64(position) + u64(matched.utf16.len())
		}
	}
	if next_source < u64(text.utf16.len()) {
		tail := text.utf16.data[int(next_source)..]
		checked_js_string_length_sum(mut vm, uint(output.len), uint(tail.len), .string_size_must_not_overflow)!
		output << tail
	}
	return Value.from_string(vm.create_string(Utf16String{data: output}))
}
