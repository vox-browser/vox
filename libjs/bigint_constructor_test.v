module libjs

import math

@[heap]
struct BigIntConstructorLog {
mut:
	events []string
}

fn bigint_constructor_test_record(mut vm VM) &Object {
	// Explicit prototype dependency, not a substitute production intrinsic.
	prototype := Object.create(vm.realm(), none)
	return BigIntConstructor.create(mut vm, vm.realm(), prototype).object
}

fn test_bigint_constructor_initialization_retains_source_order_attributes_and_constructor_identity() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	constructor := bigint_constructor_test_record(mut vm)
	value := Value.from_object(constructor)
	assert value.is_function() && value.is_constructor()
	assert constructor.own_property_keys().map(it.str()) == ['prototype', 'asIntN', 'asUintN',
		'length', 'name']
	assert voidptr(constructor.internal_get_prototype_of()?) == voidptr(vm.realm().function_prototype_record())
	assert constructor.get(mut vm, PropertyName.from_str('name'))!.as_string().str() == 'BigInt'
	assert constructor.get(mut vm, PropertyName.from_str('length'))!.number == 1
	prototype := constructor.internal_get_own_property(PropertyName.from_str('prototype'))?
	assert !prototype.writable? && !prototype.enumerable? && !prototype.configurable?
	backref :=
		prototype.value?.as_object().internal_get_own_property(PropertyName.from_str('constructor'))?
	assert voidptr(backref.value?.as_object()) == voidptr(constructor)
	assert backref.writable? && backref.configurable? && !backref.enumerable?
	for name in ['name', 'length'] {
		descriptor := constructor.internal_get_own_property(PropertyName.from_str(name))?
		assert !descriptor.writable? && !descriptor.enumerable? && descriptor.configurable?
	}
	for name in ['asIntN', 'asUintN'] {
		descriptor := constructor.internal_get_own_property(PropertyName.from_str(name))?
		assert descriptor.writable? && descriptor.configurable? && !descriptor.enumerable?
		method := descriptor.value?.as_object()
		assert method.get(mut vm, PropertyName.from_str('name'))!.as_string().str() == name
		assert method.get(mut vm, PropertyName.from_str('length'))!.number == 2
		assert voidptr(method.internal_get_prototype_of()?) == voidptr(vm.realm().function_prototype_record())
		result := call(mut vm, Value.from_object(method), js_null(), [
			Value.from_i32(4),
			Value.from_string(vm.create_string_from_str('31')),
		])!
		assert result.str() == if name == 'asIntN' {
			'-1n'
		} else {
			'15n'
		}
	}
}

fn test_bigint_constructor_call_converts_integral_numbers_and_coerces_object_only_once() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	constructor := Value.from_object(bigint_constructor_test_record(mut vm))
	for number, expected in {
		0.0:                '0n'
		-42.0:              '-42n'
		9007199254740994.0: '9007199254740994n'
		1e30:               '1000000000000000019884624838656n'
	} {
		assert call(mut vm, constructor, js_null(), [Value.from_f64(number)])!.str() == expected
	}
	for text, expected in {
		'':            '0n'
		' \n00100\n ': '100n'
		'0Xff':        '255n'
		'0b101':       '5n'
		'-123':        '-123n'
	} {
		assert call(mut vm, constructor, js_null(), [
			Value.from_string(vm.create_string_from_str(text)),
		])!.str() == expected
	}
	assert call(mut vm, constructor, js_null(), [Value.from_bool(true)])!.str() == '1n'
	assert call(mut vm, constructor, js_null(), [Value.from_bool(false)])!.str() == '0n'
	integer := Value.from_bigint(string_to_bigint(utf16_string('123')) or { panic('fixture') })
	mut log := &BigIntConstructorLog{}
	for argument in [Value.from_i32(123), Value.from_string(vm.create_string_from_str('123')),
		integer] {
		mut object := Object.create(vm.realm(), none)
		coercion := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [argument, mut log] (mut vm VM) !Value {
			log.events << vm.argument(0).as_string().str()
			return argument
		}, 1, PropertyName.from_str('coerce'), none)
		object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
			Value.from_object(coercion.object), 7)
		result := call(mut vm, constructor, js_null(), [Value.from_object(object)])!
		assert result.str() == '123n' && log.events == ['number']
		if argument.is_bigint() { assert voidptr(result.as_bigint()) == voidptr(integer.as_bigint())
		 }
		log.events.clear()
	}
	// OrdinaryToPrimitive tries valueOf before toString for the number hint.
	mut object := Object.create(vm.realm(), none)
	for name in ['valueOf', 'toString'] {
		method := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [name, object, mut log] (mut vm VM) !Value {
			log.events << name
			if name == 'valueOf' { return Value.from_object(object) }
			return Value.from_string(vm.create_string_from_str('123'))
		}, 0, PropertyName.from_str(name), none)
		object.define_direct_property(PropertyName.from_str(name),
			Value.from_object(method.object), 7)
	}
	assert call(mut vm, constructor, js_null(), [Value.from_object(object)])!.str() == '123n'
	assert log.events == ['valueOf', 'toString']
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_bigint_constructor_errors_propagate_and_construct_throws_without_coercion_or_prototype_reads() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	constructor := Value.from_object(bigint_constructor_test_record(mut vm))
	for argument in [js_null(), js_undefined(), Value.from_symbol(Symbol.create(none, .unique))] {
		if _ := call(mut vm, constructor, js_null(), [argument]) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
	}
	if _ := call(mut vm, constructor, js_null(), []Value{}) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()?.str() == 'Cannot convert undefined to BigInt'
	}
	for number in [1.23, math.nan(), math.inf(1), math.inf(-1)] {
		if _ := call(mut vm, constructor, js_null(), [Value.from_f64(number)]) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == 'Cannot convert non-integral number to BigInt'
		}
	}
	mut poison := Object.create(vm.realm(), none)
	thrower := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(77))
	}, 1, PropertyName.from_str('thrower'), none)
	poison.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(thrower.object), 7)
	if _ := call(mut vm, constructor, js_null(), [Value.from_object(poison)]) {
		assert false
	} else {
		assert thrown_value(err).number == 77
	}
	mut new_target := NativeFunction.create_constructor(mut vm, vm.realm(),
		vm.realm().function_prototype, fn (mut vm VM) !Value {
		return js_undefined()
	}, fn (mut vm VM, target &Object) !&Object {
		return Object.create(vm.realm(), none)
	}, 0, PropertyName.from_str('HostConstructor')).object
	new_target.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('prototype'), fn (mut vm VM) !Value {
		assert false, 'BigInt [[Construct]] must not read newTarget.prototype'
		return js_undefined()
	}, unsafe { nil }, 0, vm.realm().function_prototype)
	for target in [constructor.as_object(), new_target] {
		if _ := construct(mut vm, constructor, [Value.from_object(poison)], target) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == 'BigInt is not a constructor'
		}
	}
	assert call(mut vm, constructor, js_null(), [Value.from_i32(42)])!.str() == '42n'
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
