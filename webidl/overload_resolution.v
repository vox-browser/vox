// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebIDL/OverloadResolution.{h,cpp}.
module webidl

pub struct ResolvedOverload {
pub:
	callable_id int
	// none represents Web IDL's special "missing" argument value.
	arguments []?Value
}

pub fn is_platform_object(value Value) bool {
	return value.kind == .platform_object
}

pub fn platform_object_implements_interface(value Value, interface_name string) bool {
	return is_platform_object(value) && interface_name in value.platform_interfaces
}

enum OverloadTypeMatch {
	nullable_or_dictionary
	platform_interface_or_object
	array_buffer_or_object
	data_view_or_object
	typed_array_or_object
	callable_or_object
	sequence
	dictionary_or_object
	boolean
	numeric
	bigint
	string_
	any
}

fn type_is_dictionary(type_ &Type, dictionary_types []string) bool {
	return type_.name() in dictionary_types
}

fn typed_array_name(source BufferSource) string {
	return match source.kind {
		.int8_array { 'Int8Array' }
		.uint8_array { 'Uint8Array' }
		.uint8_clamped_array { 'Uint8ClampedArray' }
		.int16_array { 'Int16Array' }
		.uint16_array { 'Uint16Array' }
		.int32_array { 'Int32Array' }
		.uint32_array { 'Uint32Array' }
		.bigint64_array { 'BigInt64Array' }
		.biguint64_array { 'BigUint64Array' }
		.float32_array { 'Float32Array' }
		.float64_array { 'Float64Array' }
		else { '' }
	}
}

fn direct_type_matches(type_ &Type, condition OverloadTypeMatch, value Value, dictionary_types []string) bool {
	return match condition {
		.nullable_or_dictionary {
			type_.is_nullable() || type_is_dictionary(type_, dictionary_types)
		}
		.platform_interface_or_object {
			platform_object_implements_interface(value, type_.name()) || type_.is_object()
		}
		.array_buffer_or_object {
			(type_.is_plain() && type_.name() in ['ArrayBuffer', 'BufferSource'])
				|| type_.is_object()
		}
		.data_view_or_object {
			(type_.is_plain()
				&& type_.name() in ['DataView', 'BufferSource', 'ArrayBufferView'])
				|| type_.is_object()
		}
		.typed_array_or_object {
			source := value.buffer_value or { return type_.is_object() }
			(type_.is_plain()
				&& type_.name() in [typed_array_name(source), 'BufferSource', 'ArrayBufferView'])
				|| type_.is_object()
		}
		.callable_or_object {
			// Callback function types remain a generator-side FIXME upstream.
			type_.is_object()
		}
		.sequence {
			type_.name() == 'sequence'
		}
		.dictionary_or_object {
			type_is_dictionary(type_, dictionary_types) || type_.is_object()
		}
		.boolean {
			type_.is_boolean()
		}
		.numeric {
			type_.is_numeric()
		}
		.bigint {
			type_.is_bigint()
		}
		.string_ {
			type_.is_string()
		}
		.any {
			type_.is_any()
		}
	}
}

// Most distinguishing-argument steps also accept matching flattened union
// members. Annotated inner types remain unimplemented in upstream Ladybird.
fn type_or_union_matches(type_ &Type, condition OverloadTypeMatch, value Value, dictionary_types []string) bool {
	if direct_type_matches(type_, condition, value, dictionary_types) {
		return true
	}
	if type_.is_union() {
		for member in type_.as_union().flattened_member_types() {
			if direct_type_matches(member, condition, value, dictionary_types) {
				return true
			}
		}
	}
	return false
}

fn (mut overloads EffectiveOverloadSet) select_matching_argument(index int, condition OverloadTypeMatch, value Value, dictionary_types []string) bool {
	if index < 0 {
		return false
	}
	for item_index, item in overloads.items_ {
		if index >= item.types.len || index >= item.optionality_values.len {
			continue
		}
		if type_or_union_matches(item.types[index], condition, value, dictionary_types) {
			overloads.last_matching_item_index_ = item_index
			return true
		}
	}
	overloads.last_matching_item_index_ = none
	return false
}

fn (mut overloads EffectiveOverloadSet) select_optional_argument(index int) bool {
	if index < 0 {
		return false
	}
	for item_index, item in overloads.items_ {
		if index < item.optionality_values.len && item.optionality_values[index] == .optional {
			overloads.last_matching_item_index_ = item_index
			return true
		}
	}
	overloads.last_matching_item_index_ = none
	return false
}

// https://webidl.spec.whatwg.org/#es-overloads
pub fn resolve_overload(mut overloads EffectiveOverloadSet, arguments []Value, dictionary_types []string) !ResolvedOverload {
	argument_count := if overloads.is_empty() {
		0
	} else {
		declared_count := overloads.items_[0].types.len
		if arguments.len < declared_count { arguments.len } else { declared_count }
	}
	if overloads.is_empty() {
		return error('TypeError: overload resolution failed')
	}

	distinguishing_argument_index := if overloads.size() > 1 {
		int(overloads.distinguishing_argument_index())
	} else {
		-1
	}
	mut values := []?Value{}
	mut index := 0

	for index < distinguishing_argument_index {
		value := arguments[index]
		item := overloads.items_[0]
		type_ := item.types[index]
		optionality := item.optionality_values[index]
		if optionality == .optional && value.kind == .undefined {
			values << none
		} else {
			values << convert_ecmascript_type_to_idl_value(value, type_)
		}
		index++
	}

	mut iterator_method_was_selected := false
	if index == distinguishing_argument_index {
		if index >= arguments.len {
			return error('TypeError: distinguishing argument is missing')
		}
		value := arguments[index]
		if value.kind == .undefined && overloads.select_optional_argument(index) {
			overloads.remove_all_other_entries()
		} else if value.kind in [.undefined, .null_]
			&& overloads.select_matching_argument(index, .nullable_or_dictionary, value, dictionary_types) {
			overloads.remove_all_other_entries()
		} else if is_platform_object(value)
			&& overloads.select_matching_argument(index, .platform_interface_or_object, value, dictionary_types) {
			overloads.remove_all_other_entries()
		} else if value.kind == .buffer_source
			&& (value.buffer_value or { BufferSource{} }).is_array_buffer()
			&& overloads.select_matching_argument(index, .array_buffer_or_object, value, dictionary_types) {
			overloads.remove_all_other_entries()
		} else if value.kind == .buffer_source
			&& (value.buffer_value or { BufferSource{} }).is_data_view()
			&& overloads.select_matching_argument(index, .data_view_or_object, value, dictionary_types) {
			overloads.remove_all_other_entries()
		} else if value.kind == .buffer_source
			&& (value.buffer_value or { BufferSource{} }).is_typed_array()
			&& overloads.select_matching_argument(index, .typed_array_or_object, value, dictionary_types) {
			overloads.remove_all_other_entries()
		} else if value.kind == .callback
			&& overloads.select_matching_argument(index, .callable_or_object, value, dictionary_types) {
			overloads.remove_all_other_entries()
		} else if value.kind == .sequence
			&& overloads.select_matching_argument(index, .sequence, value, dictionary_types) {
			overloads.remove_all_other_entries()
			iterator_method_was_selected = true
		} else if value.kind == .object
			&& overloads.select_matching_argument(index, .dictionary_or_object, value, dictionary_types) {
			overloads.remove_all_other_entries()
		} else if value.kind == .boolean
			&& overloads.select_matching_argument(index, .boolean, value, dictionary_types) {
			overloads.remove_all_other_entries()
		} else if value.kind == .number
			&& overloads.select_matching_argument(index, .numeric, value, dictionary_types) {
			overloads.remove_all_other_entries()
		} else if value.kind == .bigint
			&& overloads.select_matching_argument(index, .bigint, value, dictionary_types) {
			overloads.remove_all_other_entries()
		} else if overloads.select_matching_argument(index, .string_, value, dictionary_types) {
			overloads.remove_all_other_entries()
		} else if overloads.select_matching_argument(index, .numeric, value, dictionary_types) {
			overloads.remove_all_other_entries()
		} else if overloads.select_matching_argument(index, .boolean, value, dictionary_types) {
			overloads.remove_all_other_entries()
		} else if overloads.select_matching_argument(index, .bigint, value, dictionary_types) {
			overloads.remove_all_other_entries()
		} else if overloads.select_matching_argument(index, .any, value, dictionary_types) {
			overloads.remove_all_other_entries()
		} else {
			return error('TypeError: overload resolution failed')
		}
	}

	callable := overloads.only_item()
	if index == distinguishing_argument_index && iterator_method_was_selected {
		// Value already contains the translated sequence produced by @@iterator.
		values << arguments[index]
		index++
	}
	for index < argument_count {
		value := arguments[index]
		type_ := callable.types[index]
		optionality := callable.optionality_values[index]
		if optionality == .optional && value.kind == .undefined {
			values << none
		} else {
			values << convert_ecmascript_type_to_idl_value(value, type_)
		}
		index++
	}
	for index < callable.types.len {
		if callable.optionality_values[index] != .variadic {
			values << none
		}
		index++
	}
	return ResolvedOverload{
		callable_id: callable.callable_id
		arguments: values
	}
}
