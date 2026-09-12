module webidl

fn observe_set(_ int, value Value) ! {
	if value.kind != .string_ {
		return error('TypeError: expected string')
	}
}

fn observe_expected_index(index int, value Value) ! {
	if value.kind != .number || int(value.number_value) != index {
		return error('InvalidStateError: callback received the wrong index')
	}
}

fn reject_delete(value Value) ! {
	if value.string_value == 'keep' {
		return error('InvalidStateError: retained')
	}
}

fn test_observable_array_callbacks_and_clear_observation() {
	mut array := ObservableArray.create()
	array.set_on_set_an_indexed_value_callback(observe_set)
	array.set_on_delete_an_indexed_value_callback(reject_delete)
	array.append(string_value('keep'))!
	assert array.values[0].string_value == 'keep'
	if _ := array.delete(0) {
		assert false
	} else {
		assert err.msg().starts_with('InvalidStateError:')
	}
	if _ := array.clear() {
		assert false, 'clear must invoke and propagate the delete callback'
	} else {
		assert err.msg().starts_with('InvalidStateError:')
	}
	assert array.values.len == 1
	array.values[0] = string_value('remove')
	array.clear()!
	assert array.values.len == 0
}

fn overload_item(callable_id int, type_ &Type, optionality Optionality) EffectiveOverloadSetItem {
	return EffectiveOverloadSetItem{
		callable_id: callable_id
		types: [type_]
		optionality_values: [optionality]
	}
}

fn resolve_one_argument(items []EffectiveOverloadSetItem, argument Value, dictionaries []string) !ResolvedOverload {
	mut overloads := EffectiveOverloadSet.new(items, 0)
	return resolve_overload(mut overloads, [argument], dictionaries)
}

fn test_overload_resolution_distinguishing_primitive_precedence() {
	items := [
		overload_item(1, Type.new('DOMString', false), .required),
		overload_item(2, Type.new('double', false), .required),
		overload_item(3, Type.new('boolean', false), .required),
		overload_item(4, Type.new('bigint', false), .required),
		overload_item(5, Type.new('any', false), .required),
	]
	assert resolve_one_argument(items, string_value('x'), [])!.callable_id == 1
	assert resolve_one_argument(items, number_value(2), [])!.callable_id == 2
	assert resolve_one_argument(items, boolean_value(true), [])!.callable_id == 3
	assert resolve_one_argument(items, bigint_value(9), [])!.callable_id == 4
	// The string conversion fallback precedes numeric, boolean, bigint, and any.
	assert resolve_one_argument(items, object_value(map[string]Value{}), [])!.callable_id == 1
}

fn test_overload_resolution_optional_nullable_dictionary_and_union() {
	optional_items := [
		overload_item(1, Type.new('DOMString', false), .required),
		overload_item(2, Type.new('double', false), .optional),
	]
	resolved_optional := resolve_one_argument(optional_items, undefined_value(), [])!
	assert resolved_optional.callable_id == 2
	assert resolved_optional.arguments == [?Value(none)]

	dictionary_items := [
		overload_item(3, Type.new('Options', false), .required),
		overload_item(4, Type.new('DOMString', false), .required),
	]
	assert resolve_one_argument(dictionary_items, null_value(), ['Options'])!.callable_id == 3

	nullable_number := Type.new('double', true)
	union_type := UnionType.new('(DOMString or double?)', false, [
		Type.new('DOMString', false),
		nullable_number,
	])
	union_items := [
		overload_item(5, &union_type.Type, .required),
		overload_item(6, Type.new('object', false), .required),
	]
	assert resolve_one_argument(union_items, null_value(), [])!.callable_id == 5
}

fn test_overload_resolution_platform_and_buffer_precedence() {
	platform_items := [
		overload_item(1, Type.new('Node', false), .required),
		overload_item(2, Type.new('object', false), .required),
	]
	assert resolve_one_argument(platform_items, platform_object_value_with_interfaces([
		'Node',
	]), [])!.callable_id == 1
	assert is_platform_object(platform_object_value())
	assert platform_object_implements_interface(platform_object_value_with_interfaces([
		'Node',
	]), 'Node')

	buffer_items := [
		overload_item(3, Type.new('Uint16Array', false), .required),
		overload_item(4, Type.new('ArrayBufferView', false), .required),
		overload_item(5, Type.new('object', false), .required),
	]
	typed := BufferSource.view(.uint16_array, [u8(0), 1], 0, 2)!
	assert resolve_one_argument(buffer_items, buffer_source_value(typed), [])!.callable_id == 3
}

fn test_overload_resolution_sequence_and_missing_arguments() {
	sequence := ParameterizedType.new('sequence', false, [
		Type.new('DOMString', false),
	])
	items := [
		overload_item(1, &sequence.Type, .required),
		overload_item(2, Type.new('object', false), .required),
	]
	resolved := resolve_one_argument(items, sequence_value([string_value('a')]), [])!
	assert resolved.callable_id == 1
	assert resolved.arguments[0] or { panic('sequence argument was marked missing') } == sequence_value([
		string_value('a'),
	])

	mut single := EffectiveOverloadSet.new([
		EffectiveOverloadSetItem{
			callable_id: 7
			types: [Type.new('DOMString', false), Type.new('double', false)]
			optionality_values: [.required, .optional]
		},
	], 0)
	missing := resolve_overload(mut single, [string_value('present')], [])!
	assert missing.arguments.len == 2
	assert missing.arguments[1] == none
}

fn test_observable_internal_operations_use_index_callbacks() {
	mut array := ObservableArray.create()
	array.set_on_set_an_indexed_value_callback(observe_expected_index)
	assert array.internal_set(2, number_value(2))!
	assert array.values[2].number_value == 2
	array.append(number_value(3))!
	assert array.values[3].number_value == 3
	assert array.internal_delete(0)!
	assert array.values.len == 3
}
