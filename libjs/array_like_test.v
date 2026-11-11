module libjs

@[heap]
struct ArrayLikeReads {
mut:
	keys []string
}

fn test_array_like_lists_read_length_once_then_indices_including_inherited_holes() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut parent := Object.create(vm.realm(), none)
	parent.create_data_property(mut vm, PropertyName.from_number(1), Value.from_i32(17)) or {
		panic(err)
	}
	mut object := Object.create(vm.realm(), parent)
	object.create_data_property(mut vm, PropertyName.from_number(3), Value.from_i32(42)) or {
		panic(err)
	}
	mut reads := &ArrayLikeReads{}
	object.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('length'), fn [mut reads] (mut vm VM) !Value {
		reads.keys << 'length'
		return Value.from_f64(4.9)
	}, unsafe { nil }, attribute_configurable, none)
	object.define_native_accessor(mut vm, vm.realm(), PropertyName.from_number(0), fn [mut reads] (mut vm VM) !Value {
		reads.keys << '0'
		mut receiver := vm.this_value().as_object()
		// The list retains the length measured before this mutation.
		receiver.define_direct_property(PropertyName.from_str('length'), Value.from_i32(0), 7)
		return Value.from_i32(1)
	}, unsafe { nil }, 0, none)
	values := create_list_from_array_like(mut vm, Value.from_object(object), unsafe { nil })!
	assert values.len == 4
	assert values[0].number == 1 && values[1].number == 17
	assert values[2].is_undefined() && values[3].number == 42
	assert reads.keys == ['length', '0']
	assert length_of_array_like(mut vm, object)! == 0
}

fn test_array_like_length_and_index_failures_stop_before_later_effects() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	for failure in ['length', '0', '1'] {
		mut object := Object.create(vm.realm(), none)
		mut reads := &ArrayLikeReads{}
		for name in ['length', '0', '1', '2'] {
			object.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str(name), fn [mut reads, name, failure] (mut vm VM) !Value {
				reads.keys << name
				if name == failure { return throw_completion(Value.from_i32(17)) }
				return Value.from_i32(3)
			}, unsafe { nil }, 0, none)
		}
		if _ := create_list_from_array_like(mut vm, Value.from_object(object), unsafe { nil }) {
			assert false
		} else {
			assert thrown_value(err).number == 17
		}
		assert reads.keys == match failure {
			'length' { ['length'] }
			'0' { ['length', '0'] }
			else { ['length', '0', '1'] }
		}

		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}

fn test_array_like_checks_each_element_before_reading_the_next_index() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut object := Object.create(vm.realm(), none)
	object.create_data_property(mut vm, PropertyName.from_str('length'), Value.from_i32(3)) or {
		panic(err)
	}
	object.create_data_property(mut vm, PropertyName.from_number(0), Value.from_i32(1)) or {
		panic(err)
	}
	object.create_data_property(mut vm, PropertyName.from_number(1), js_null()) or { panic(err) }
	object.define_native_accessor(mut vm, vm.realm(), PropertyName.from_number(2), fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(99))
	}, unsafe { nil }, 0, none)
	if _ := create_list_from_array_like(mut vm, Value.from_object(object), fn (mut vm VM, value Value) ! {
		if !value.is_number() { return throw_completion(Value.from_i32(17)) }
	})
	{
		assert false
	} else {
		assert thrown_value(err).number == 17
	}
	for value in [js_null(), js_undefined(), Value.from_i32(42),
		Value.from_string(vm.create_string_from_str('abc'))] {
		if _ := create_list_from_array_like(mut vm, value, unsafe { nil }) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
	}
	object.define_direct_property(PropertyName.from_str('length'), Value.from_i32(-1), 7)
	assert create_list_from_array_like(mut vm, Value.from_object(object), unsafe { nil })!.len == 0
	object.define_direct_property(PropertyName.from_str('length'), Value.from_f64(2147483648.0), 7)
	object.define_native_accessor(mut vm, vm.realm(), PropertyName.from_number(0), fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(77))
	}, unsafe { nil }, 0, none)
	if _ := create_list_from_array_like(mut vm, Value.from_object(object), unsafe { nil }) {
		assert false
	} else {
		assert thrown_value(err).as_i32() == 77
	}
}
