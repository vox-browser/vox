module libjs

import math

fn string_search_call(mut vm VM, last bool, receiver Value, arguments []Value) !Value {
	function := NativeFunction.create_raw(mut vm, vm.realm(), vm.realm().function_prototype, if last {
		NativeFunctionPointer(string_prototype_last_index_of)
	} else {
		NativeFunctionPointer(string_prototype_index_of)
	}, 1, PropertyName.from_str(if last { 'lastIndexOf' } else { 'indexOf' }), none)
	return call(mut vm, Value.from_object(function.object), receiver, arguments)
}

fn test_string_search_helpers_and_native_bodies_find_code_unit_offsets_and_empty_needles() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	text := Value.from_string(vm.create_string_from_str('hello friends'))
	friends := Value.from_string(vm.create_string_from_str('friends'))
	needle := Value.from_string(vm.create_string_from_str('e'))
	empty := Value.from_string(vm.empty_string())
	assert string_search_call(mut vm, false, text, [friends])!.number == 6
	assert string_search_call(mut vm, false, text, [friends, Value.from_i32(7)])!.number == -1
	assert string_search_call(mut vm, false, text, [needle, Value.from_i32(2)])!.number == 9
	assert string_search_call(mut vm, true, text, [needle])!.number == 9
	assert string_search_call(mut vm, true, text, [needle, Value.from_i32(-7)])!.number == -1
	assert string_search_call(mut vm, true, text, [empty])!.number == 13
	assert string_search_call(mut vm, true, text, [empty, Value.from_i32(4)])!.number == 4
	assert string_search_call(mut vm, false, text, [empty, Value.from_f64(math.inf(1))])!.number == 13
	assert string_search_call(mut vm, false, text, [needle, Value.from_f64(math.nan())])!.number == 1
	assert string_search_call(mut vm, true, text, [needle, Value.from_f64(math.nan())])!.number == 9
	for last in [false, true] {
		assert string_search_call(mut vm, last, text, []Value{})!.number == -1
		assert string_search_call(mut vm, last, text, [
			Value.from_string(vm.create_string_from_str('a very long needle')),
		])!.number == -1
		pair := Value.from_string(vm.create_string_from_str('😀'))
		for index, unit in [u16(0xd83d), 0xde00] {
			search := Value.from_string(vm.create_string(Utf16String.from_slice([unit])))
			assert string_search_call(mut vm, last, pair, [search])!.number == index
		}
		assert string_search_call(mut vm, last, pair, [pair])!.number == 0
	}
	assert string_index_of(utf16_string('aa'), utf16_string('a'), ~uint(0)) == none
	assert string_index_of(utf16_string('aa'), utf16_string(''), 3) == none
	assert string_index_of(utf16_string('aa'), utf16_string(''), 2)? == 2
	assert string_last_index_of(utf16_string('aaa'), utf16_string('aa'), 1)? == 1
}

@[heap]
struct StringSearchLog {
mut:
	events []string
}

fn test_string_search_conversion_order_and_last_index_nan_rule_precede_impossible_match_fast_path() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut log := &StringSearchLog{}
	mut values := []Value{}
	for name in ['receiver', 'needle', 'position'] {
		mut object := Object.create(vm.realm(), none)
		converter := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [name, mut log] (mut vm VM) !Value {
			log.events << name + ':' + vm.argument(0).as_string().str()
			if name == 'position' { return throw_completion(Value.from_i32(77)) }
			return Value.from_string(vm.create_string_from_str(if name == 'needle' {
				'too long'
			} else {
				'x'
			}))
		}, 1, PropertyName.from_str('convert'), none)
		object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
			Value.from_object(converter.object), 7)
		values << Value.from_object(object)
	}
	for last in [false, true] {
		if _ := string_search_call(mut vm, last, values[0], values[1..]) {
			assert false
		} else {
			assert thrown_value(err).number == 77
		}
		assert log.events == ['receiver:string', 'needle:string', 'position:number']
		log.events.clear()
		if _ := string_search_call(mut vm, last, js_null(), values[1..]) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
		assert log.events.len == 0
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
