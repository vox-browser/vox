module libjs

import math

@[heap]
struct TypedArrayCreateLog {
mut:
	arguments []Value
	calls     int
}

fn test_typed_array_create_validates_results_and_checks_only_a_sole_numeric_minimum() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	parent := Object.create(realm, none)
	buffer := ArrayBufferObject.create(mut vm, realm, 2, parent)!
	array := TypedArray.create(realm, .uint8, 2, buffer, parent)
	mut log := &TypedArrayCreateLog{}
	function := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype, fn (mut vm VM) !Value {
		return js_undefined()
	}, fn [array, mut log] (mut vm VM, target &Object) !&Object {
		log.arguments = vm.running_execution_context().arguments().clone()
		log.calls++
		return array.object
	}, 0, PropertyName.from_str('Host'))
	for arguments in [
		[]Value{},
		[Value.from_i32(2)],
		[Value.from_f64(1.5)],
		[Value.from_i32(-1)],
		[Value.from_f64(math.nan())],
		[Value.from_f64(math.inf(-1))],
		[Value.from_string(vm.create_string_from_str('3'))],
		[Value.from_bigint(string_to_bigint(utf16_string('3')) or { panic('invalid BigInt literal') })],
		[Value.from_bool(true)],
		[Value.from_i32(3), js_undefined()],
	] {
		assert voidptr(typed_array_create(mut vm, function.object, arguments)!) == voidptr(array)
		assert log.arguments.len == arguments.len
		for index, argument in arguments {
			assert same_value(log.arguments[index], argument)
		}
	}
	for value in [Value.from_i32(3), Value.from_f64(2.5), Value.from_f64(math.inf(1))] {
		if _ := typed_array_create(mut vm, function.object, [value]) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
			assert thrown_value(err).as_object().error_message()?.str() == 'Invalid typed array length'
		}
	}
	assert log.calls == 13 && vm.running_execution_context() == base
		&& vm.interpreter_stack().depth() == 0
}

fn test_typed_array_create_rejects_fake_detached_and_out_of_bounds_results_before_size_checks() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	parent := Object.create(realm, none)
	for mode in ['fake', 'detached', 'out of bounds'] {
		mut buffer := ArrayBufferObject.create(mut vm, realm, 2, parent)!
		buffer.maximum_byte_length = uint(4)
		array := TypedArray.create(realm, .uint8, 2, buffer, parent)
		mut fake := Object.create(realm, parent)
		fake.class_name = 'TypedArray'
		if mode == 'detached' { detach_array_buffer(mut vm, mut buffer, none)! }
		if mode == 'out of bounds' { assert buffer.try_resize(1, true)
		 }
		result := if mode == 'fake' { fake } else { array.object }
		function := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype, fn (mut vm VM) !Value {
			return js_undefined()
		}, fn [result] (mut vm VM, target &Object) !&Object {
			return result
		}, 0, PropertyName.from_str('Host'))
		for args in [[]Value{}, [Value.from_i32(99)]] {
			if _ := typed_array_create(mut vm, function.object, args) {
				assert false
			} else {
				assert thrown_value(err).as_object().error_kind()? == .type_error
				assert thrown_value(err).as_object().error_message()?.str() != 'Invalid typed array length'
			}
		}
	}
}

fn test_typed_array_create_retains_requested_number_across_constructor_mutation_and_propagates_errors() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	parent := Object.create(realm, none)
	buffer := ArrayBufferObject.create(mut vm, realm, 2, parent)!
	array := TypedArray.create(realm, .uint8, 2, buffer, parent)
	mut state := &TypedArrayCreateLog{
		arguments: [Value.from_i32(2)]
	}
	function := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype, fn (mut vm VM) !Value {
		return js_undefined()
	}, fn [array, mut state] (mut vm VM, target &Object) !&Object {
		assert vm.argument(0).number == 2
		state.arguments[0] = Value.from_i32(99)
		return array.object
	}, 0, PropertyName.from_str('Host'))
	assert voidptr(typed_array_create(mut vm, function.object, state.arguments)!) == voidptr(array)
	assert state.arguments[0].number == 99
	throwing := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype, fn (mut vm VM) !Value {
		return js_undefined()
	}, fn (mut vm VM, target &Object) !&Object {
		return throw_completion(Value.from_i32(17))
	}, 0, PropertyName.from_str('Throwing'))
	if _ := typed_array_create(mut vm, throwing.object, []Value{}) {
		assert false
	} else {
		assert thrown_value(err).number == 17
	}
	if _ := typed_array_create(mut vm, parent, []Value{}) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
