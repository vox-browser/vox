// SPDX-License-Identifier: BSD-2-Clause
// Regressions for Ladybird 82ba30cd14b4e7e6e18a912db549d341ba84f251.
module libjs

import math

@[heap]
struct ArgumentLimitReads {
mut:
	keys []string
}

fn argument_limit_array(mut vm VM, length f64, mut reads ArgumentLimitReads) &Object {
	mut object := Object.create(vm.realm(), none)
	object.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('length'), fn [length, mut reads] (mut vm VM) !Value {
		reads.keys << 'length'
		return Value.from_f64(length)
	}, unsafe { nil }, 0, none)
	object.define_native_accessor(mut vm, vm.realm(), PropertyName.from_number(0), fn [mut reads] (mut vm VM) !Value {
		reads.keys << '0'
		return throw_completion(Value.from_i32(77))
	}, unsafe { nil }, 0, none)
	return object
}

fn test_argument_list_rejects_impossible_lengths_before_elements_in_all_call_paths() {
	for length in [f64(maximum_argument_count + 1), 268435456.0, 9007199254740991.0, math.inf(1)] {
		for method in ['apply', 'reflect_apply', 'reflect_construct'] {
			mut vm := VM.create()
			context := create_simple_execution_context(mut vm)
			mut reads := &ArgumentLimitReads{}
			list := argument_limit_array(mut vm, length, mut reads)
			target := vm.realm().boolean_constructor_record()
			function := NativeFunction.create(mut vm, vm.realm(), none, fn [method, target, list] (mut vm VM) !Value {
				if method == 'apply' {
					apply := target.get(mut vm, PropertyName.from_str('apply'))!
					return call(mut vm, apply, Value.from_object(target), [js_null(), Value.from_object(list)])
				}
				callback := if method == 'reflect_apply' { NativeFunctionPointer(reflect_apply) } else { NativeFunctionPointer(reflect_construct) }
				native := NativeFunction.create_raw(mut vm, vm.realm(), none, callback, 2,
					PropertyName.from_str(method), none)
				arguments := if method == 'reflect_apply' {
					[Value.from_object(target), js_null(), Value.from_object(list)]
				} else {
					[Value.from_object(target), Value.from_object(list)]
				}
				return call(mut vm, Value.from_object(native.object), js_undefined(), arguments)
			}, 0, PropertyName.from_str('invoke'), none)
			if _ := call(mut vm, Value.from_object(function.object), js_undefined(), []Value{}) {
				assert false
			} else {
				assert thrown_value(err).as_object().error_kind()? == .internal_error
				assert thrown_value(err).as_object().error_message()?.str() == 'Call stack size limit exceeded'
			}
			assert reads.keys == ['length']
			assert vm.running_execution_context() == context
			assert vm.interpreter_stack().depth() == 0
		}
	}
}

fn argument_limit_convert_list(mut vm VM, list &Object, is_argument_list bool) ![]Value {
	if is_argument_list { return create_argument_list_from_array_like(mut vm, Value.from_object(list)) }
	return create_list_from_array_like(mut vm, Value.from_object(list), unsafe { nil })
}

fn test_general_array_like_lists_retain_first_element_errors_for_huge_lengths() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for is_argument_list in [false, true] {
		mut reads := &ArgumentLimitReads{}
		length := if is_argument_list { f64(maximum_argument_count) } else { math.inf(1) }
		list := argument_limit_array(mut vm, length, mut reads)
		if _ := argument_limit_convert_list(mut vm, list, is_argument_list) {
			assert false
		} else {
			assert thrown_value(err).as_i32() == 77
		}
		assert reads.keys == ['length', '0']
	}
}
