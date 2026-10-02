module libjs

import math

@[heap]
struct MathTestLog { mut: closed int }

fn math_test_run(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'math.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 10000 })
}

fn test_math_is_installed_with_intrinsic_ancestry_and_source_metadata() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	object := realm.math_object_record()
	assert realm.global_object_record().get(mut vm, PropertyName.from_str('Math'))!.as_object() == object
	assert object.internal_get_prototype_of()? == realm.object_prototype_record()
	for prototype in [realm.function_prototype_record(), realm.boolean_prototype_record(),
		realm.symbol_prototype_record(), realm.array_buffer_prototype_record(),
		realm.data_view_prototype_record(), realm.shared_array_buffer_prototype_record()] {
		assert prototype.internal_get_prototype_of()? == realm.object_prototype_record()
	}
	for name in ['E', 'LN2', 'LN10', 'LOG2E', 'LOG10E', 'PI', 'SQRT1_2', 'SQRT2'] {
		descriptor := object.internal_get_own_property(PropertyName.from_str(name))?
		assert !descriptor.writable? && !descriptor.enumerable? && !descriptor.configurable?
	}
	for name in ['abs', 'sqrt', 'ceil', 'floor', 'max', 'min', 'round', 'sumPrecise', 'f16round'] {
		descriptor := object.internal_get_own_property(PropertyName.from_str(name))?
		assert descriptor.writable? && descriptor.configurable? && !descriptor.enumerable?
		assert descriptor.value?.as_object().internal_get_prototype_of()? == realm.function_prototype_record()
	}
	assert math_test_run(mut vm, 'typeof Math;')!.as_string().utf16.str() == 'object'
	assert math_test_run(mut vm, 'Math.abs("-42");')!.number == 42
	assert math_test_run(mut vm, 'Math.imul(4294967295,5);')!.number == -5
	assert math_test_run(mut vm, 'Math.clz32(1);')!.number == 31
	assert math_test_run(mut vm, 'Math.hypot(3,4);')!.number == 5
	assert math_test_run(mut vm, 'Math.round(0.5);')!.number == 1
	assert math.signbit(math_test_run(mut vm, 'Math.round(-0.5);')!.number)
	assert math.signbit(math_test_run(mut vm, 'Math.min(0,-0);')!.number)
	assert !math.signbit(math_test_run(mut vm, 'Math.max(-0,0);')!.number)
	assert math.signbit(math_test_run(mut vm, 'Math.atan2(-0,1);')!.number)
	assert math_test_run(mut vm, 'Math.atan2(0,-0);')!.number == math.pi
	assert math_test_run(mut vm, 'Math.f16round(1.00048828125);')!.number == 1
	assert math_test_run(mut vm, 'Math.f16round(1.00146484375);')!.number == 1.001953125
	assert math_test_run(mut vm, 'Math.pow(NaN,0);')!.number == 1
	assert math.is_inf(math_test_run(mut vm, 'Math.hypot(NaN,Infinity);')!.number, 1)
}

fn test_math_random_uses_translated_xorshift_range_and_sequence() {
	mut rng := MathXorShift128Plus{ low: 1, high: 2 }
	assert rng.advance() == 8388646
	assert rng.advance() == 33816709
	for _ in 0 .. 1000 {
		value := math_random().number
		assert value >= 0 && value < 1
		assert math.floor(value * f64(u64(1) << 53)) == value * f64(u64(1) << 53)
	}
}

fn test_math_sum_precise_expansion_and_invalid_items_close_iterator() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	mut parent := Object.create(realm, realm.object_prototype_record())
	iterator_prototype := ArrayIteratorPrototype.create(mut vm, realm, parent, realm.object_prototype_record())
	values := [1e20, 1.0, -1e20, 3.0].map(Value.from_f64(it))
	array := ArrayObject.create_from(mut vm, realm, values, parent)!
	mut array_object := array.object
	iterator_fn := NativeFunction.create(mut vm, realm, realm.function_prototype,
		fn [iterator_prototype] (mut vm VM) !Value {
			return Value.from_object(ArrayIterator.create(vm.realm(), vm.this_value(),
				.value, iterator_prototype.object).object)
		}, 0, PropertyName.from_symbol(vm.well_known_symbol_iterator()), none)
	array_object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_iterator()),
		Value.from_object(iterator_fn.object), 0)
	sum := realm.math_object_record().get(mut vm, PropertyName.from_str('sumPrecise'))!
	assert call(mut vm, sum, js_undefined(), [Value.from_object(array.object)])!.number == 4
	array_object.set(mut vm, PropertyName.from_number(0), Value.from_f64(math.max_f64), .yes)!
	array_object.set(mut vm, PropertyName.from_number(1), Value.from_f64(math.max_f64), .yes)!
	array_object.set(mut vm, PropertyName.from_number(2), Value.from_f64(-math.max_f64), .yes)!
	array_object.set(mut vm, PropertyName.from_number(3), Value.from_f64(0), .yes)!
	assert call(mut vm, sum, js_undefined(), [Value.from_object(array.object)])!.number == math.max_f64
	mut log := &MathTestLog{}
	mut iterator_parent := iterator_prototype.object
	return_method := NativeFunction.create(mut vm, realm, realm.function_prototype,
		fn [mut log] (mut vm VM) !Value { log.closed++; return Value.from_object(Object.create(vm.realm(), none)) },
		0, PropertyName.from_str('return'), none)
	iterator_parent.define_direct_property(PropertyName.from_str('return'), Value.from_object(return_method.object), 0)
	array_object.set(mut vm, PropertyName.from_number(0), Value.from_string(vm.create_string_from_str('1')), .yes)!
	if _ := call(mut vm, sum, js_undefined(), [Value.from_object(array.object)]) { assert false }
	else { assert thrown_value(err).as_object().error_kind()? == .type_error }
	assert log.closed == 1
}
