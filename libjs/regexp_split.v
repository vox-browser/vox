// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn initialize_regexp_split_intrinsics(mut vm VM, mut realm Realm) {
	mut prototype := realm.regexp_prototype or { panic('Missing RegExp prototype') }
	method := NativeFunction.create(mut vm, realm, realm.function_prototype, regexp_symbol_split, 2, PropertyName.from_symbol(vm.well_known_symbol_split()), none)
	prototype.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_split()), Value.from_object(method.object), attribute_writable | attribute_configurable)
}

fn regexp_split_advance(text Utf16String, index u64, unicode bool) u64 {
	if unicode && index < u64(text.len()) { return index + u64(string_code_point_at(text, int(index)).code_unit_count) }
	return index + 1
}

// RegExpPrototype.cpp::symbol_split's generic path. A species-created sticky
// matcher owns progress, and captures are copied without string conversion.
// Original regexp state is never substituted for the matcher's lastIndex.
fn regexp_symbol_split(mut vm VM) !Value {
	if !vm.this_value().is_object() { return vm.throw_error(.type_error, 'RegExp split requires an object') }
	object := vm.this_value().as_object()
	text := vm.argument(0).to_primitive_string(mut vm)!
	limit_value := vm.argument(1)
	constructor := species_constructor(mut vm, object, vm.realm().regexp_constructor or { panic('Missing RegExp constructor') })!
	flags := object.get(mut vm, PropertyName.from_str('flags'))!.to_primitive_string(mut vm)!.utf16
	unicode := flags.data.contains(u16(`u`)) || flags.data.contains(u16(`v`))
	mut new_flags := flags
	if !flags.data.contains(u16(`y`)) {
		checked_js_string_length_sum(mut vm, uint(flags.len()), 1, .string_size_must_not_overflow)!
		new_flags = utf16_concat([flags, utf16_string('y')])
	}
	mut splitter := construct(mut vm, Value.from_object(constructor), [Value.from_object(object), Value.from_string(vm.create_string(new_flags))], none)!
	mut array := ArrayObject.create(mut vm, vm.realm(), 0, vm.realm().array_prototype_record())!.object
	limit := if limit_value.is_undefined() { u32(0xffffffff) } else { limit_value.to_u32(mut vm)! }
	if limit == 0 { return Value.from_object(array) }
	if text.is_empty() {
		result := regexp_exec(mut vm, splitter, text)!
		if result.is_null() { array.create_data_property_or_throw(mut vm, PropertyName.from_number(0), Value.from_string(text))! }
		return Value.from_object(array)
	}
	size := u64(text.utf16.len())
	mut count := u64(0)
	mut previous := u64(0)
	mut next := u64(0)
	for next < size {
		vm.consume_execution_budget()!
		splitter.set(mut vm, PropertyName.from_str('lastIndex'), Value.from_f64(f64(next)), .yes)!
		result := regexp_exec(mut vm, splitter, text)!
		if result.is_null() {
			next = regexp_split_advance(text.utf16, next, unicode)
			continue
		}
		index := splitter.get(mut vm, PropertyName.from_str('lastIndex'))!.to_length(mut vm)!
		end := if index < size { index } else { size }
		if end == previous {
			next = regexp_split_advance(text.utf16, next, unicode)
			continue
		}
		prefix := Value.from_string(vm.create_string(Utf16String.from_slice(text.utf16.data[int(previous)..int(next)])))
		array.create_data_property_or_throw(mut vm, array_index_key(count), prefix)!
		count++
		if count == u64(limit) { return Value.from_object(array) }
		previous = end
		length := length_of_array_like(mut vm, result.as_object())!
		captures := if length == 0 { u64(0) } else { length - 1 }
		for capture_index := u64(1); capture_index <= captures; capture_index++ {
			vm.consume_execution_budget()!
			capture := result.as_object().get(mut vm, array_index_key(capture_index))!
			array.create_data_property_or_throw(mut vm, array_index_key(count), capture)!
			count++
			if count == u64(limit) { return Value.from_object(array) }
		}
		next = previous
	}
	tail := Value.from_string(vm.create_string(Utf16String.from_slice(text.utf16.data[int(previous)..])))
	array.create_data_property_or_throw(mut vm, array_index_key(count), tail)!
	return Value.from_object(array)
}
