module libjs

import math

fn string_slicing_call(mut vm VM, name string, receiver Value, arguments []Value) !Value {
	behaviour := match name {
		'slice' { NativeFunctionPointer(string_prototype_slice) }
		'substring' { NativeFunctionPointer(string_prototype_substring) }
		else { NativeFunctionPointer(string_prototype_substr) }
	}

	function := NativeFunction.create_raw(mut vm, vm.realm(), vm.realm().function_prototype,
		behaviour, 2, PropertyName.from_str(name), none)
	return call(mut vm, Value.from_object(function.object), receiver, arguments)
}

fn test_string_slice_substring_substr_preserve_distinct_upstream_ranges_and_utf16_boundaries() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	text := Value.from_string(vm.create_string_from_str('hello friends'))
	for name in ['slice', 'substring', 'substr'] {
		assert string_slicing_call(mut vm, name, text, []Value{})!.as_string().str() == 'hello friends'
		assert string_slicing_call(mut vm, name, text, [Value.from_i32(1)])!.as_string().str() == 'ello friends'
		assert string_slicing_call(mut vm, name, text, [Value.from_i32(0),
			Value.from_i32(5)])!.as_string().str() == 'hello'
		assert string_slicing_call(mut vm, name, text, [Value.from_f64(math.inf(1))])!.as_string().is_empty()
		assert string_slicing_call(mut vm, name, text, [Value.from_f64(math.inf(-1))])!.as_string().str() == 'hello friends'
		assert string_slicing_call(mut vm, name, text, [Value.from_f64(1e300)])!.as_string().is_empty()
		assert string_slicing_call(mut vm, name, text, [Value.from_f64(-1e300)])!.as_string().str() == 'hello friends'
		assert string_slicing_call(mut vm, name, text, [Value.from_f64(math.nan())])!.as_string().str() == 'hello friends'
		pair := Value.from_string(vm.create_string_from_str('😀'))
		assert string_slicing_call(mut vm, name, pair, [Value.from_i32(0),
			Value.from_i32(1)])!.as_string().utf16.data == [u16(0xd83d)]
		end := if name == 'substr' { 1 } else { 2 }
		assert string_slicing_call(mut vm, name, pair, [Value.from_i32(1),
			Value.from_i32(end)])!.as_string().utf16.data == [u16(0xde00)]
	}
	assert string_slicing_call(mut vm, 'slice', text, [Value.from_i32(13),
		Value.from_i32(6)])!.as_string().is_empty()
	assert string_slicing_call(mut vm, 'substring', text, [Value.from_i32(13),
		Value.from_i32(6)])!.as_string().str() == 'friends'
	assert string_slicing_call(mut vm, 'substr', text, [Value.from_i32(5),
		Value.from_i32(6)])!.as_string().str() == ' frien'
	assert string_slicing_call(mut vm, 'slice', text, [Value.from_i32(-7)])!.as_string().str() == 'friends'
	assert string_slicing_call(mut vm, 'substr', text, [Value.from_i32(-7)])!.as_string().str() == 'friends'
	assert string_slicing_call(mut vm, 'substring', text, [Value.from_i32(-7)])!.as_string().str() == 'hello friends'
	assert string_slicing_call(mut vm, 'slice', text, [Value.from_i32(0),
		Value.from_i32(-1)])!.as_string().str() == 'hello friend'
	assert string_slicing_call(mut vm, 'substr', text, [Value.from_i32(-3),
		Value.from_i32(-5)])!.as_string().is_empty()
}

@[heap]
struct StringSlicingLog {
mut:
	events []string
}

fn test_string_slicing_converts_receiver_start_and_end_in_order_even_for_empty_ranges() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut log := &StringSlicingLog{}
	mut values := []Value{}
	for name in ['receiver', 'start', 'end'] {
		mut object := Object.create(vm.realm(), none)
		converter := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [name, mut log] (mut vm VM) !Value {
			log.events << name + ':' + vm.argument(0).as_string().str()
			if name == 'receiver' { return Value.from_string(vm.empty_string()) }
			if name == 'end' { return throw_completion(Value.from_i32(77)) }
			return Value.from_f64(1e300)
		}, 1, PropertyName.from_str('convert'), none)
		object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
			Value.from_object(converter.object), 7)
		values << Value.from_object(object)
	}
	for name in ['slice', 'substring', 'substr'] {
		if _ := string_slicing_call(mut vm, name, values[0], values[1..]) {
			assert false
		} else {
			assert thrown_value(err).number == 77
		}
		assert log.events == ['receiver:string', 'start:number', 'end:number']
		log.events.clear()
		if _ := string_slicing_call(mut vm, name, js_null(), values[1..]) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
		assert log.events.len == 0
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
