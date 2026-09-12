module webidl

fn matches_optional_string(type_ &Type, optionality Optionality) bool {
	return type_.is_string() && optionality == .optional
}

fn matches_bigint(type_ &Type, _ Optionality) bool {
	return type_.is_bigint()
}

fn test_overload_type_classification() {
	assert Type.new('any', false).is_any()
	assert Type.new('undefined', false).is_undefined()
	assert Type.new('boolean', false).is_boolean()
	assert Type.new('bigint', false).is_bigint()
	assert Type.new('object', false).is_object()
	assert Type.new('symbol', false).is_symbol()
	assert Type.new('DOMString', false).is_string()
	assert Type.new_enumeration('Direction', false).is_string()
	assert Type.new('unsigned long long', false).is_integer()
	assert Type.new('double', false).is_numeric()
	assert Type.new('unrestricted float', false).is_unrestricted_floating_point()
	assert Type.new('float', false).is_restricted_floating_point()
	assert !Type.new('DOMString', false).is_numeric()
}

fn test_overload_type_buffer_classification() {
	assert Type.new('ArrayBuffer', false).is_buffer()
	assert Type.new('SharedArrayBuffer', false).is_buffer_source()
	assert Type.new('DataView', false).is_buffer_view()
	assert Type.new('Uint8ClampedArray', false).is_typed_array()
	assert Type.new('Float16Array', false).is_buffer_source()
	assert !Type.new('object', false).is_buffer_source()
}

fn test_parameterized_and_union_types_flatten_members() {
	string_type := Type.new('DOMString', false)
	nullable_number := Type.new('double', true)
	undefined_type := Type.new('undefined', false)
	sequence := ParameterizedType.new('sequence', false, [string_type])
	assert sequence.Type.is_parameterized()
	assert sequence.Type.is_sequence()
	assert sequence.Type.as_parameterized() == sequence
	assert sequence.parameters() == [string_type]

	inner_union := UnionType.new('(double or undefined)', false, [nullable_number, undefined_type])
	outer_union := UnionType.new('(DOMString or double or undefined)', false, [
		string_type,
		&inner_union.Type,
	])
	assert outer_union.Type.is_union()
	assert outer_union.Type.as_union() == outer_union
	assert outer_union.flattened_member_types() == [string_type, nullable_number, undefined_type]
	assert outer_union.number_of_nullable_member_types() == 1
	assert outer_union.Type.includes_nullable_type()
	assert outer_union.Type.includes_undefined()
}

fn test_effective_overload_set_remembers_and_keeps_match() {
	string_type := Type.new('DOMString', false)
	bigint_type := Type.new('bigint', false)
	mut overloads := EffectiveOverloadSet.new([
		EffectiveOverloadSetItem{
			callable_id: 11
			types: [string_type]
			optionality_values: [.optional]
		},
		EffectiveOverloadSetItem{
			callable_id: 22
			types: [bigint_type]
			optionality_values: [.required]
		},
	], 0)
	assert !overloads.is_empty()
	assert overloads.size() == 2
	assert overloads.distinguishing_argument_index() == 0
	assert overloads.has_overload_with_matching_argument_at_index(0, matches_optional_string)
	overloads.remove_all_other_entries()
	assert overloads.size() == 1
	assert overloads.only_item().callable_id == 11
	assert !overloads.has_overload_with_matching_argument_at_index(0, matches_bigint)
}
