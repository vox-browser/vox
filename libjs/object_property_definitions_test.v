module libjs

fn definition_descriptor(mut vm VM, value Value) &Object {
	mut descriptor := Object.create(vm.realm(), none)
	descriptor.create_data_property(PropertyName.from_str('value'), value)
	descriptor.create_data_property(PropertyName.from_str('writable'), Value.from_bool(true))
	descriptor.create_data_property(PropertyName.from_str('enumerable'), Value.from_bool(true))
	descriptor.create_data_property(PropertyName.from_str('configurable'), Value.from_bool(true))
	return descriptor
}

@[heap]
struct PropertyDefinitionReads {
mut:
	keys []string
}

fn test_bulk_definitions_preserve_own_key_order_and_skip_non_enumerable_or_private_entries() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut target := Object.create(vm.realm(), none)
	mut properties := Object.create(vm.realm(), none)
	mut reads := &PropertyDefinitionReads{}
	symbol := Symbol.create(utf16_string('public'), .unique)
	private := Symbol.create_private()
	for key in [PropertyName.from_str('last'), PropertyName.from_number(9),
		PropertyName.from_number(3), PropertyName.from_symbol(symbol)] {
		name := key.str()
		getter := NativeFunction.create(mut vm, vm.realm(), none, fn [mut reads, name] (mut vm VM) !Value {
			reads.keys << name
			return Value.from_object(definition_descriptor(mut vm, Value.from_i32(42)))
		}, 0, key, 'get')
		properties.define_direct_accessor(key, getter.object, none, attribute_enumerable)
	}
	ignored_getter := NativeFunction.create(mut vm, vm.realm(), none, fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(17))
	}, 0, PropertyName.from_str('ignored'), 'get')
	properties.define_direct_accessor(PropertyName.from_str('hidden'), ignored_getter.object, none,
		0)
	properties.define_direct_accessor(PropertyName.from_symbol(private), ignored_getter.object,
		none, attribute_enumerable)
	result := target.define_properties(mut vm, properties)!
	assert result == target
	assert reads.keys == ['3', '9', 'last', 'Symbol(public)']
	assert target.own_property_keys().len == 4
	assert target.get(mut vm, PropertyName.from_symbol(symbol))!.number == 42
	assert !target.has_own_property(PropertyName.from_str('hidden'))
	assert !target.has_own_property(PropertyName.from_symbol(private))
}

fn test_bulk_descriptor_conversion_failure_leaves_the_target_unchanged() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	for throw_getter in [false, true] {
		mut target := Object.create(vm.realm(), none)
		target.create_data_property(PropertyName.from_str('first'), Value.from_i32(1))
		mut properties := Object.create(vm.realm(), none)
		properties.create_data_property(PropertyName.from_str('first'), Value.from_object(definition_descriptor(mut vm,
			Value.from_i32(42))))
		if throw_getter {
			getter := NativeFunction.create(mut vm, vm.realm(), none, fn (mut vm VM) !Value {
				return throw_completion(Value.from_i32(17))
			}, 0, PropertyName.from_str('second'), 'get')
			properties.define_direct_accessor(PropertyName.from_str('second'), getter.object, none,
				attribute_enumerable)
		} else {
			properties.create_data_property(PropertyName.from_str('second'), js_undefined())
		}
		if _ := target.define_properties(mut vm, properties) {
			assert false
		} else {
			if throw_getter {
				assert thrown_value(err).number == 17
			} else {
				assert thrown_value(err).as_object().error_kind()? == .type_error
			}
		}
		assert target.get(mut vm, PropertyName.from_str('first'))!.number == 1
		assert target.own_property_keys().len == 1
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}

fn test_bulk_definition_failure_retains_earlier_writes_after_gathering_all_descriptors() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut target := Object.create(vm.realm(), none)
	target.define_direct_property(PropertyName.from_str('locked'), Value.from_i32(1), 0)
	mut properties := Object.create(vm.realm(), none)
	mut reads := &PropertyDefinitionReads{}
	for name in ['first', 'locked', 'last'] {
		getter := NativeFunction.create(mut vm, vm.realm(), none, fn [mut reads, name] (mut vm VM) !Value {
			reads.keys << name
			return Value.from_object(definition_descriptor(mut vm, Value.from_i32(42)))
		}, 0, PropertyName.from_str(name), 'get')
		properties.define_direct_accessor(PropertyName.from_str(name), getter.object, none,
			attribute_enumerable)
	}
	if _ := target.define_properties(mut vm, properties) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
	assert reads.keys == ['first', 'locked', 'last']
	assert target.get(mut vm, PropertyName.from_str('first'))!.number == 42
	assert target.get(mut vm, PropertyName.from_str('locked'))!.number == 1
	assert !target.has_own_property(PropertyName.from_str('last'))
}

fn test_descriptor_getters_can_remove_later_source_properties_before_their_turn() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut target := Object.create(vm.realm(), none)
	mut properties := Object.create(vm.realm(), none)
	first := PropertyName.from_str('first')
	second := PropertyName.from_str('second')
	getter := NativeFunction.create(mut vm, vm.realm(), none, fn [mut properties, second] (mut vm VM) !Value {
		assert properties.internal_delete(second)
		return Value.from_object(definition_descriptor(mut vm, Value.from_i32(42)))
	}, 0, first, 'get')
	properties.define_direct_accessor(first, getter.object, none, attribute_enumerable)
	properties.create_data_property(second, js_undefined())
	target.define_properties(mut vm, properties)!
	assert target.get(mut vm, first)!.number == 42
	assert !target.has_own_property(second)
}
