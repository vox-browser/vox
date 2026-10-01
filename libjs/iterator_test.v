module libjs

@[heap]
struct IteratorTestState {
mut:
	events    []string
	arguments []Value
	receiver  Value
	index     int
}

fn iterator_test_record(mut vm VM, behaviour NativeFunctionPointer) &IteratorRecord {
	mut object := Object.create(vm.realm(), none)
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype,
		behaviour, 0, PropertyName.from_str('next'), none)
	object.define_direct_property(PropertyName.from_str('next'), Value.from_object(function.object), 7)
	return get_iterator_direct(mut vm, object) or { panic(err.msg()) }
}

fn test_iterator_acquisition_caches_next_without_callability_validation() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut log := &IteratorTestState{}
	mut iterator := Object.create(vm.realm(), none)
	result := create_iterator_result_object(vm.realm(), Value.from_i32(42), false, none)
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype,
		fn [mut log, result] (mut vm VM) !Value {
		log.events << 'next'
		log.receiver = vm.this_value()
		log.arguments = vm.running_execution_context().arguments().clone()
		return Value.from_object(result)
	}, 0, PropertyName.from_str('next'), none)
	iterator.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('next'),
		fn [mut log, function] (mut vm VM) !Value {
		log.events << 'get next'
		return Value.from_object(function.object)
	}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
	mut iterable := Object.create(vm.realm(), none)
	method := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype,
		fn [mut log, iterator, iterable] (mut vm VM) !Value {
		assert voidptr(vm.this_value().as_object()) == voidptr(iterable)
		assert vm.argument_count() == 0
		log.events << 'iterator'
		return Value.from_object(iterator)
	}, 0, PropertyName.from_str('iterator'), none)
	iterable.define_native_accessor(mut vm, vm.realm(), PropertyName.from_symbol(vm.well_known_symbol_iterator()),
		fn [mut log, method] (mut vm VM) !Value {
		log.events << 'get iterator'
		return Value.from_object(method.object)
	}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
	mut record := get_iterator_sync(mut vm, iterable)!
	assert !record.done && voidptr(record.iterator) == voidptr(iterator)
	assert log.events == ['get iterator', 'iterator', 'get next']
	iterator.define_direct_property(PropertyName.from_str('next'), Value.from_i32(17), 7)
	for argument in [?Value(none), ?Value(js_undefined()), ?Value(Value.from_i32(9))] {
		next := iterator_next(mut vm, mut record, argument)!
		assert voidptr(next) == voidptr(result)
		assert voidptr(log.receiver.as_object()) == voidptr(iterator)
		assert log.arguments == if supplied := argument { [supplied] } else { []Value{} }
	}
	assert log.events == ['get iterator', 'iterator', 'get next', 'next', 'next', 'next']
	mut invalid := get_iterator_direct(mut vm, iterator)!
	assert !invalid.done && invalid.next_method.number == 17
	if _ := iterator_next(mut vm, mut invalid, none) { assert false } else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
	assert invalid.done
	for value in [js_undefined(), js_null(), Value.from_i32(0)] {
		iterable.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_iterator()), value, 7)
		if _ := get_iterator_sync(mut vm, iterable) { assert false } else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
	}
	bad_method := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype,
		fn (mut vm VM) !Value { return js_null() }, 0, PropertyName.from_str('bad'), none)
	if _ := get_iterator_from_method(mut vm, js_null(), Value.from_object(bad_method.object)) {
		assert false
	} else { assert thrown_value(err).as_object().error_kind()? == .type_error }
}

fn test_iterator_step_defers_value_errors_and_marks_abrupt_exhaustion() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	for mode in ['next throws', 'next primitive', 'done throws', 'value throws', 'exhausted'] {
		mut log := &IteratorTestState{}
		mut result := create_iterator_result_object(vm.realm(), js_undefined(), false, none)
		result.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('done'),
			fn [mut log, mode] (mut vm VM) !Value {
			log.events << 'done'
			if mode == 'done throws' { return throw_completion(Value.from_i32(17)) }
			return if mode == 'exhausted' { Value.from_i32(1) } else { Value.from_i32(0) }
		}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
		result.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('value'),
			fn [mut log] (mut vm VM) !Value {
			log.events << 'value'
			return throw_completion(Value.from_i32(42))
		}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
		mut record := iterator_test_record(mut vm, fn [mut log, mode, result] (mut vm VM) !Value {
			log.events << 'next'
			if mode == 'next throws' { return throw_completion(Value.from_i32(9)) }
			if mode == 'next primitive' { return js_undefined() }
			return Value.from_object(result)
		})
		if mode == 'value throws' {
			step := iterator_step(mut vm, mut record)!
			assert !record.done && !step.done
			assert step.result.done.number == 0
			assert step.result.value.is_error() && step.result.value.value.number == 42
			assert log.events == ['next', 'done', 'value']
			if _ := iterator_step_value(mut vm, mut record) { assert false } else {
				assert thrown_value(err).number == 42
			}
		} else if mode == 'exhausted' {
			step := iterator_step_value(mut vm, mut record)!
			assert step.done && step.value.is_undefined()
			assert log.events == ['next', 'done']
		} else {
			if _ := iterator_step(mut vm, mut record) { assert false } else {
				failure := thrown_value(err)
				if mode == 'next primitive' { assert failure.as_object().error_kind()? == .type_error }
				else { assert failure.number == if mode == 'next throws' { 9 } else { 17 } }
			}
			assert log.events == if mode == 'done throws' { ['next', 'done'] } else { ['next'] }
		}
		assert record.done
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}

fn test_iterator_collection_distinguishes_yielded_undefined_from_done_and_result_descriptors() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	result := create_iterator_result_object(vm.realm(), js_undefined(), false, prototype)
	assert voidptr(result.prototype?) == voidptr(prototype)
	assert result.own_property_keys().map(it.str()) == ['value', 'done']
	for key in result.own_property_keys() {
		descriptor := result.internal_get_own_property(key)?
		assert descriptor.writable? && descriptor.enumerable? && descriptor.configurable?
	}
	assert !iterator_complete(mut vm, result)!
	assert iterator_value(mut vm, result)!.is_undefined()
	mut log := &IteratorTestState{}
	mut record := iterator_test_record(mut vm, fn [mut log, prototype] (mut vm VM) !Value {
		index := log.index
		log.index++
		return Value.from_object(create_iterator_result_object(vm.realm(),
			if index == 0 { js_undefined() } else { Value.from_i32(index) }, index == 3, prototype))
	})
	assert iterator_to_list(mut vm, mut record)! == [js_undefined(), Value.from_i32(1), Value.from_i32(2)]
	assert record.done && log.index == 4
	// [[Done]] records completion; IteratorNext does not consult it to skip calls.
	_ := iterator_next(mut vm, mut record, none)!
	assert log.index == 5
}

fn test_iterator_close_observes_return_before_preserving_original_throw_priority() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for mode in ['missing', 'null', 'not callable', 'get throws', 'call throws', 'primitive', 'object'] {
		for initial in [normal_completion(Value.from_i32(5)), Completion{type_: .return_, value: Value.from_i32(6)},
			Completion{type_: .throw_, value: Value.from_i32(7)}] {
			mut log := &IteratorTestState{}
			mut record := iterator_test_record(mut vm, fn (mut vm VM) !Value { return js_undefined() })
			mut iterator := record.iterator
			method := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype,
				fn [mut log, mode, iterator] (mut vm VM) !Value {
				log.events << 'call'
				assert voidptr(vm.this_value().as_object()) == voidptr(iterator)
				assert vm.argument_count() == 0
				if mode == 'call throws' { return throw_completion(Value.from_i32(42)) }
				return if mode == 'object' { Value.from_object(iterator) } else { js_undefined() }
			}, 0, PropertyName.from_str('return'), none)
			if mode != 'missing' {
				iterator.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('return'),
					fn [mut log, mode, method] (mut vm VM) !Value {
					log.events << 'get'
					if mode == 'get throws' { return throw_completion(Value.from_i32(17)) }
					if mode == 'null' { return js_null() }
					if mode == 'not callable' { return Value.from_i32(9) }
					return Value.from_object(method.object)
				}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
			}
			result := iterator_close(mut vm, record, initial)
			if initial.is_error() || mode in ['missing', 'null', 'object'] {
				assert result.type_ == initial.type_ && result.value == initial.value
			} else {
				assert result.is_error()
				if mode in ['get throws', 'call throws'] {
					assert result.value.number == if mode == 'get throws' { 17 } else { 42 }
				} else { assert result.value.as_object().error_kind()? == .type_error }
			}
			assert log.events == if mode == 'missing' { []string{} }
				else if mode in ['null', 'not callable', 'get throws'] { ['get'] } else { ['get', 'call'] }
			assert !record.done
		}
	}
}

fn test_iterator_close_all_visits_reverse_order_and_keeps_first_reverse_failure() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut log := &IteratorTestState{}
	mut records := []&IteratorRecord{}
	for index in 0 .. 3 {
		record := iterator_test_record(mut vm, fn (mut vm VM) !Value { return js_undefined() })
		mut iterator := record.iterator
		function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype,
			fn [mut log, index] (mut vm VM) !Value {
			log.events << index.str()
			return throw_completion(Value.from_i32(index))
		}, 0, PropertyName.from_str('return'), none)
		iterator.define_direct_property(PropertyName.from_str('return'), Value.from_object(function.object), 7)
		records << record
	}
	result := iterator_close_all(mut vm, records, normal_completion(Value.from_i32(42)))
	assert result.is_error() && result.value.number == 2
	assert log.events == ['2', '1', '0']
	assert records.all(!it.done)
	assert iterator_close_all(mut vm, []&IteratorRecord{}, normal_completion(js_undefined())).value.is_undefined()
}
