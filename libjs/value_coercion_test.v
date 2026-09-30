module libjs

fn define_coercion_method(mut vm VM, mut object Object, key PropertyName, behaviour NativeFunctionPointer) {
	function := NativeFunction.create(mut vm, vm.realm(), none, behaviour, 0, key, none)
	object.define_direct_property(key, Value.from_object(function.object),
		attribute_writable | attribute_configurable)
}

fn test_ordinary_coercion_uses_hint_order_receiver_and_fallback() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut prototype := Object.create(vm.realm(), none)
	define_coercion_method(mut vm, mut prototype, PropertyName.from_str('valueOf'), fn (mut vm VM) !Value {
		mut object := vm.this_value().as_object()
		log := object.get(PropertyName.from_str('log')).as_string().str()
		object.define_direct_property(PropertyName.from_str('log'), Value.from_string(vm.create_string_from_str(
			log + 'v')), 7)
		return vm.this_value()
	})
	define_coercion_method(mut vm, mut prototype, PropertyName.from_str('toString'), fn (mut vm VM) !Value {
		mut object := vm.this_value().as_object()
		log := object.get(PropertyName.from_str('log')).as_string().str()
		object.define_direct_property(PropertyName.from_str('log'), Value.from_string(vm.create_string_from_str(
			log + 't')), 7)
		return Value.from_string(vm.create_string_from_str('42'))
	})
	mut object := Object.create(vm.realm(), prototype)
	object.define_direct_property(PropertyName.from_str('log'),
		Value.from_string(vm.empty_string()), 7)
	value := Value.from_object(object)
	assert value.to_number(mut vm)!.number == 42
	assert object.get(PropertyName.from_str('log')).as_string().str() == 'vt'
	object.define_direct_property(PropertyName.from_str('log'),
		Value.from_string(vm.empty_string()), 7)
	text := value.to_primitive_string(mut vm)!
	assert text.str() == '42'
	assert object.get(PropertyName.from_str('log')).as_string().str() == 't'
	// Non-callable ordinary methods are skipped; their presence does not throw.
	object.define_direct_property(PropertyName.from_str('valueOf'), Value.from_i32(7), 7)
	assert value.to_number(mut vm)!.number == 42
	assert is_loosely_equal(mut vm, value, Value.from_i32(42))!
	assert compare_primitive_values(mut vm, value, Value.from_i32(43))! == .less
}

fn test_exotic_coercion_receives_default_number_and_string_hints() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut object := Object.create(vm.realm(), none)
	object.define_direct_property(PropertyName.from_str('primitive'),
		Value.from_string(vm.create_string_from_str('17')), 7)
	define_coercion_method(mut vm, mut object,
		PropertyName.from_symbol(vm.well_known_symbol_to_primitive()), fn (mut vm VM) !Value {
		assert vm.argument_count() == 1
		mut receiver := vm.this_value().as_object()
		receiver.define_direct_property(PropertyName.from_str('hint'), vm.argument(0), 7)
		return receiver.get(PropertyName.from_str('primitive'))
	})
	value := Value.from_object(object)
	assert add(mut vm, value, Value.from_i32(1))!.as_string().str() == '171'
	assert object.get(PropertyName.from_str('hint')).as_string().str() == 'default'
	assert value.to_number(mut vm)!.number == 17
	assert object.get(PropertyName.from_str('hint')).as_string().str() == 'number'
	assert value.to_bigint(mut vm)!.big_integer.str() == '17'
	assert object.get(PropertyName.from_str('hint')).as_string().str() == 'number'
	text := value.to_primitive_string(mut vm)!
	assert text.str() == '17'
	assert object.get(PropertyName.from_str('hint')).as_string().str() == 'string'
	assert value.to_property_key(mut vm)!.str() == '17'
	assert object.get(PropertyName.from_str('hint')).as_string().str() == 'string'
	integer := string_to_bigint(utf16_string('42'))?
	object.define_direct_property(PropertyName.from_str('primitive'), Value.from_bigint(integer), 7)
	assert value.to_numeric(mut vm)!.str() == '42n'
	assert is_loosely_equal(mut vm, value, Value.from_i32(42))!
	assert is_loosely_equal(mut vm, Value.from_i32(42), value)!
	assert !is_strictly_equal(value, Value.from_bigint(integer))
	symbol := Symbol.create(utf16_string('key'), .unique)
	object.define_direct_property(PropertyName.from_str('primitive'), Value.from_symbol(symbol), 7)
	assert value.to_property_key(mut vm)!.as_symbol() == symbol
	assert is_loosely_equal(mut vm, value, Value.from_symbol(symbol))!
}

fn test_coercion_preserves_left_to_right_order_and_live_method_replacement() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut log := Object.create(vm.realm(), none)
	log.define_direct_property(PropertyName.from_str('text'), Value.from_string(vm.empty_string()),
		7)
	mut left := Object.create(vm.realm(), none)
	mut right := Object.create(vm.realm(), none)
	for i in 0 .. 2 {
		mut object := if i == 0 { left } else { right }
		define_coercion_method(mut vm, mut object, PropertyName.from_str('valueOf'), fn [mut log, i] (mut vm VM) !Value {
			text := log.get(PropertyName.from_str('text')).as_string().str()
			log.define_direct_property(PropertyName.from_str('text'), Value.from_string(vm.create_string_from_str(
				text + i.str())), 7)
			return Value.from_i32(i + 1)
		})
	}
	assert add(mut vm, Value.from_object(left), Value.from_object(right))!.number == 3
	assert log.get(PropertyName.from_str('text')).as_string().str() == '01'
	define_coercion_method(mut vm, mut left, PropertyName.from_str('valueOf'), fn (mut vm VM) !Value {
		return Value.from_i32(40)
	})
	assert add(mut vm, Value.from_object(left), Value.from_object(right))!.number == 42
	assert log.get(PropertyName.from_str('text')).as_string().str() == '011'
}

fn test_exotic_and_ordinary_coercion_errors_preserve_completion_and_frames() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut object := Object.create(vm.realm(), none)
	key := PropertyName.from_symbol(vm.well_known_symbol_to_primitive())
	value := Value.from_object(object)
	object.define_direct_property(key, Value.from_i32(42), 7)
	if _ := value.to_primitive(mut vm) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()? == '42 is not a function'
	}
	define_coercion_method(mut vm, mut object, key, fn (mut vm VM) !Value {
		return vm.this_value()
	})
	if _ := value.to_primitive(mut vm) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()? == 'Can\'t convert [object Object] to primitive with hint "default", its @@toPrimitive method returned an object'
	}
	object.define_direct_property(key, js_null(), 7)
	if _ := value.to_number(mut vm) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()? == 'Cannot convert object to number'
	}
	define_coercion_method(mut vm, mut object, PropertyName.from_str('valueOf'), fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(7))
	})
	if _ := value.to_number(mut vm) {
		assert false
	} else {
		assert thrown_value(err).number == 7
	}
	assert vm.running_execution_context() == base
	assert vm.execution_context_stack().len == 1
	assert vm.interpreter_stack().depth() == 0
}
