module webidl

fn observe_set(value Value) ! {
	if value.kind != .string_ {
		return error('TypeError: expected string')
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

fn test_overload_resolution_type_arity_optional_and_variadic() {
	candidates := [
		EffectiveOverload{
			callable_id: 1
			arguments:   [
				OverloadArgument{
					type_: IDLType{
						kind: .string_
					}
				},
			]
		},
		EffectiveOverload{
			callable_id: 2
			arguments:   [
				OverloadArgument{
					type_: IDLType{
						kind: .numeric
					}
				},
			]
		},
		EffectiveOverload{
			callable_id: 3
			arguments:   [
				OverloadArgument{
					type_:    IDLType{
						kind: .boolean
					}
					variadic: true
				},
			]
		},
	]
	assert resolve_overload(candidates, [string_value('x')])!.callable_id == 1
	assert resolve_overload(candidates, [number_value(2)])!.callable_id == 2
	assert resolve_overload(candidates, [boolean_value(true),
		boolean_value(false)])!.callable_id == 3
	// With no object/interface branch, Web IDL's primitive conversion fallback
	// gives the string overload precedence for an ordinary object.
	assert resolve_overload(candidates, [object_value(map[string]Value{})])!.callable_id == 1
}

fn test_overload_distinguishing_precedence_beats_any_fallback() {
	candidates := [
		EffectiveOverload{
			callable_id: 1
			arguments:   [
				OverloadArgument{
					type_: IDLType{
						kind: .any
					}
				},
			]
		},
		EffectiveOverload{
			callable_id: 2
			arguments:   [
				OverloadArgument{
					type_: IDLType{
						kind: .numeric
					}
				},
			]
		},
	]
	assert resolve_overload(candidates, [number_value(1)])!.callable_id == 2
}

fn test_observable_internal_operations_use_index_callbacks() {
	mut array := ObservableArray.create()
	array.set_on_set_an_indexed_value_callback(observe_set)
	assert array.internal_set(0, string_value('value'))!
	assert array.values[0].string_value == 'value'
	assert array.internal_delete(0)!
	assert array.values.len == 0
}
