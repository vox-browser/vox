module libjs

import math

fn sort_default_compare(mut vm VM, x Value, y Value) !f64 {
	return compare_array_elements(mut vm, x, y, none)
}

fn test_sort_indexed_properties_gathers_inherited_entries_and_handles_holes_before_comparison() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut parent := Object.create(vm.realm(), none)
	assert parent.create_data_property(mut vm, PropertyName.from_number(1), Value.from_i32(17))!
	mut object := Object.create(vm.realm(), parent)
	assert object.create_data_property(mut vm, PropertyName.from_number(3), Value.from_i32(42))!
	assert object.create_data_property(mut vm, PropertyName.from_number(4), js_undefined())!
	values := sort_indexed_properties(mut vm, object, 5, sort_default_compare, .skip_holes)!
	assert values.map(it.str()) == ['17', '42', 'undefined']
	through_holes := sort_indexed_properties(mut vm, object, 5, sort_default_compare,
		.read_through_holes)!
	assert through_holes.map(it.str()) == ['17', '42', 'undefined', 'undefined', 'undefined']
	assert object.own_property_keys().map(it.str()) == ['3', '4']
	// Numeric default ordering is lexical, as in the upstream algorithm.
	array := ArrayObject.create_from(mut vm, vm.realm(), [Value.from_i32(2),
		Value.from_i32(10), Value.from_i32(1)], parent)!
	assert sort_indexed_properties(mut vm, array.object, 3, sort_default_compare, .skip_holes)!.map(it.str()) == [
		'1',
		'10',
		'2',
	]
}

@[heap]
struct ArraySortEffects {
mut:
	reads       []int
	comparisons int
	throw_on    int
	pairs       []string
}

fn test_array_sort_reads_every_index_before_comparing_and_stops_on_first_abrupt_completion() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut state := &ArraySortEffects{}
	mut object := Object.create(vm.realm(), none)
	for index in 0 .. 4 {
		object.define_native_accessor(mut vm, vm.realm(), PropertyName.from_number(u32(index)), fn [mut state, index] (mut vm VM) !Value {
			state.reads << index
			if index == state.throw_on - 1 { return throw_completion(Value.from_i32(17)) }
			return Value.from_i32(3 - index)
		}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
	}
	compare := fn [mut state] (mut vm VM, x Value, y Value) !f64 {
		state.comparisons++
		assert state.reads == [0, 1, 2, 3]
		if state.comparisons == state.throw_on { return throw_completion(Value.from_i32(42)) }
		return x.number - y.number
	}
	assert sort_indexed_properties(mut vm, object, 4, compare, .read_through_holes)!.map(it.number) == [
		0.0,
		1,
		2,
		3,
	]
	assert state.reads == [0, 1, 2, 3] && state.comparisons > 0
	state.reads.clear()
	state.comparisons = 0
	state.throw_on = 2
	if _ := sort_indexed_properties(mut vm, object, 4, compare, .read_through_holes) {
		assert false
	} else {
		assert thrown_value(err).number == 17
	}
	assert state.reads == [0, 1] && state.comparisons == 0
	state.throw_on = 0
	state.reads.clear()
	compare_error := fn [mut state] (mut vm VM, x Value, y Value) !f64 {
		state.comparisons++
		assert state.reads == [0, 1, 2, 3]
		return throw_completion(Value.from_i32(42))
	}
	if _ := sort_indexed_properties(mut vm, object, 4, compare_error, .skip_holes) {
		assert false
	} else {
		assert thrown_value(err).number == 42
	}
	assert state.comparisons == 1
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_array_merge_sort_is_stable_and_preserves_the_upstream_comparison_sequence() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut items := []Value{}
	for id, rank in [2, 1, 2, 1, 2, 1, 2] {
		mut object := Object.create(vm.realm(), none)
		assert object.create_data_property(mut vm, PropertyName.from_str('rank'),
			Value.from_i32(rank))!
		assert object.create_data_property(mut vm, PropertyName.from_str('id'), Value.from_i32(id))!
		items << Value.from_object(object)
	}
	array_merge_sort(mut vm, fn (mut vm VM, x Value, y Value) !f64 {
		return x.as_object().get(mut vm, PropertyName.from_str('rank'))!.number - y.as_object().get(mut vm,
			PropertyName.from_str('rank'))!.number
	}, mut items)!
	mut ids := []int{}
	for item in items {
		ids << item.as_object().get(mut vm, PropertyName.from_str('id'))!.as_i32()
	}
	assert ids == [1, 3, 5, 0, 2, 4, 6]
	mut trace := &ArraySortEffects{}
	mut numbers := [Value.from_i32(4), Value.from_i32(3), Value.from_i32(2),
		Value.from_i32(1)]
	array_merge_sort(mut vm, fn [mut trace] (mut vm VM, x Value, y Value) !f64 {
		trace.pairs << '${x.str()},${y.str()}'
		return x.number - y.number
	}, mut numbers)!
	assert trace.pairs == ['4,3', '2,1', '3,1', '3,2']
	assert numbers.map(it.number) == [1.0, 2, 3, 4]
	for size in [0, 1] {
		mut short := []Value{len: size, init: Value.from_i32(42)}
		array_merge_sort(mut vm, fn (mut vm VM, x Value, y Value) !f64 {
			assert false
			return 0
		}, mut short)!
		assert short.len == size
	}
}

fn test_compare_array_elements_orders_utf16_and_undefined_and_normalizes_comparator_nan() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	function := NativeFunction.create_raw(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		assert false
		return js_undefined()
	}, 2, PropertyName.from_str('unreachable'), none)
	assert compare_array_elements(mut vm, js_undefined(), js_undefined(), function.object)! == 0
	assert compare_array_elements(mut vm, js_undefined(), Value.from_i32(1), function.object)! == 1
	assert compare_array_elements(mut vm, Value.from_i32(1), js_undefined(), function.object)! == -1
	for result in [math.nan(), -0.0, 17.0] {
		comparator := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [result] (mut vm VM) !Value {
			assert vm.this_value().is_undefined() && vm.argument_count() == 2
			assert vm.argument(0).number == 1 && vm.argument(1).number == 2
			return Value.from_f64(result)
		}, 2, PropertyName.from_str('compare'), none)
		actual := compare_array_elements(mut vm, Value.from_i32(1), Value.from_i32(2),
			comparator.object)!
		if math.is_nan(result) {
			assert actual == 0 && !math.signbit(actual)
		} else {
			assert actual == result && math.signbit(actual) == math.signbit(result)
		}
	}
	for texts in [['2', '10'], ['😀', '\ue000'], ['a', 'aa'],
		['b', 'a']] {
		left := Value.from_string(vm.create_string_from_str(texts[0]))
		right := Value.from_string(vm.create_string_from_str(texts[1]))
		expected := if left.as_string().utf16 < right.as_string().utf16 { -1.0 } else { 1.0 }
		assert compare_array_elements(mut vm, left, right, none)! == expected
	}
}

fn test_array_element_comparison_preserves_coercion_order_and_comparator_result_errors() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut trace := &ArraySortEffects{}
	mut objects := []&Object{}
	for label in ['left', 'right', 'result'] {
		mut object := Object.create(vm.realm(), none)
		method := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut trace, label] (mut vm VM) !Value {
			trace.pairs << label
			assert vm.argument(0).as_string().str() == if label == 'result' {
				'number'
			} else {
				'string'
			}
			if label == 'result' { return Value.from_f64(math.nan()) }
			return Value.from_string(vm.create_string_from_str(label))
		}, 1, PropertyName.from_str('coerce'), none)
		assert object.create_data_property(mut vm,
			PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
			Value.from_object(method.object))!
		objects << object
	}
	left := Value.from_object(objects[0])
	right := Value.from_object(objects[1])
	assert compare_array_elements(mut vm, left, right, none)! == -1
	assert trace.pairs == ['left', 'right']
	trace.pairs.clear()
	result_object := objects[2]
	comparator := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut trace, result_object] (mut vm VM) !Value {
		trace.pairs << 'compare'
		return Value.from_object(result_object)
	}, 2, PropertyName.from_str('compare'), none)
	assert compare_array_elements(mut vm, left, right, comparator.object)! == 0
	assert trace.pairs == ['compare', 'result']
	trace.pairs.clear()
	thrower := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut trace] (mut vm VM) !Value {
		trace.pairs << 'throw'
		return throw_completion(Value.from_i32(17))
	}, 1, PropertyName.from_str('throw'), none)
	mut result := result_object
	assert result.create_data_property(mut vm,
		PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(thrower.object))!
	if _ := compare_array_elements(mut vm, left, right, comparator.object) {
		assert false
	} else {
		assert thrown_value(err).number == 17
	}
	assert trace.pairs == ['compare', 'throw']
	trace.pairs.clear()
	mut left_object := objects[0]
	assert left_object.create_data_property(mut vm,
		PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(thrower.object))!
	if _ := compare_array_elements(mut vm, left, right, none) {
		assert false
	} else {
		assert thrown_value(err).number == 17
	}
	assert trace.pairs == ['throw']
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
