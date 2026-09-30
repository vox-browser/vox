module libjs

@[heap]
struct AccessorState {
mut:
	value     Value
	events    []string
	receivers []Value
	throw_get bool
	throw_set bool
}

fn accessor_host(mut vm VM, mut state AccessorState) &Object {
	mut host := Object.create(vm.realm(), none)
	getter := NativeFunction.create(mut vm, vm.realm(), none, fn [mut state] (mut vm VM) !Value {
		assert vm.argument_count() == 0
		state.events << 'get'
		state.receivers << vm.this_value()
		if state.throw_get { return throw_completion(Value.from_i32(17)) }
		return state.value
	}, 0, PropertyName.from_str('value'), 'get')
	setter := NativeFunction.create(mut vm, vm.realm(), none, fn [mut state] (mut vm VM) !Value {
		assert vm.argument_count() == 1
		state.events << 'set'
		state.receivers << vm.this_value()
		if state.throw_set { return throw_completion(Value.from_i32(23)) }
		state.value = vm.argument(0)
		return Value.from_i32(-1)
	}, 1, PropertyName.from_str('value'), 'set')
	assert host.internal_define_own_property(PropertyName.from_str('value'), PropertyDescriptor{
		getter:       Value.from_object(getter.object)
		setter:       Value.from_object(setter.object)
		enumerable:   true
		configurable: true
	})
	return host
}

fn test_ordinary_accessors_preserve_receiver_and_never_create_receiver_properties() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut state := &AccessorState{
		value: Value.from_i32(41)
	}
	mut parent := accessor_host(mut vm, mut state)
	mut child := Object.create(vm.realm(), parent)
	key := PropertyName.from_str('value')
	assert child.get(mut vm, key)!.number == 41
	child.set(mut vm, key, Value.from_i32(42), .yes)!
	assert state.value.number == 42
	assert !child.has_own_property(key)
	assert state.events == ['get', 'set']
	for receiver in state.receivers {
		assert receiver.as_object() == child
	}
	// An accessor may also be called with a primitive receiver.
	assert parent.internal_get(mut vm, key, Value.from_i32(7))!.number == 42
	assert parent.internal_set(mut vm, key, Value.from_i32(43), js_null())!
	assert state.receivers[2].number == 7 && state.receivers[3].is_null()
	descriptor := parent.internal_get_own_property(key)?
	assert descriptor.is_accessor_descriptor() && !descriptor.is_data_descriptor()
	assert descriptor.value == none && descriptor.writable == none
	assert descriptor.getter?.is_function() && descriptor.setter?.is_function()
	assert descriptor.enumerable? && descriptor.configurable?
	assert vm.running_execution_context() == base
	assert vm.interpreter_stack().depth() == 0
}

fn test_undefined_accessors_and_data_receivers_follow_ordinary_set_rules() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	key := PropertyName.from_str('value')
	mut host := Object.create(vm.realm(), none)
	assert host.internal_define_own_property(key, PropertyDescriptor{ getter: js_undefined() })
	assert host.get(mut vm, key)!.is_undefined()
	assert !host.internal_set(mut vm, key, Value.from_i32(42), Value.from_object(host))!
	host.set(mut vm, key, Value.from_i32(42), .no)!
	if _ := host.set(mut vm, key, Value.from_i32(42), .yes) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
	mut data := Object.create(vm.realm(), none)
	data.create_data_property(key, Value.from_i32(1))
	assert !data.internal_set(mut vm, key, Value.from_i32(42), Value.from_object(host))!
	assert !data.internal_set(mut vm, key, Value.from_i32(42), js_null())!
	assert host.internal_get_own_property(key)?.is_accessor_descriptor()
	assert data.get(mut vm, key)!.number == 1
}

fn test_descriptor_transitions_preserve_attributes_and_reset_kind_specific_fields() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut state := &AccessorState{
		value: Value.from_i32(42)
	}
	mut host := accessor_host(mut vm, mut state)
	key := PropertyName.from_str('value')
	initial := host.internal_get_own_property(key)?
	// Accessor -> data: omitted value/writable use defaults.
	assert host.internal_define_own_property(key, PropertyDescriptor{ writable: true })
	data := host.internal_get_own_property(key)?
	assert data.is_data_descriptor() && data.getter == none && data.setter == none
	assert data.value?.is_undefined() && data.writable?
	assert data.enumerable? && data.configurable?
	assert host.internal_define_own_property(key, PropertyDescriptor{ getter: initial.getter? })
	accessor := host.internal_get_own_property(key)?
	assert accessor.is_accessor_descriptor() && accessor.setter?.is_undefined()
	assert accessor.enumerable? && accessor.configurable?
	assert host.get(mut vm, key)!.number == 42
	assert host.internal_define_own_property(key, PropertyDescriptor{ enumerable: false })
	updated := host.internal_get_own_property(key)?
	assert !updated.enumerable? && updated.configurable?
	assert same_value(updated.getter?, initial.getter?)
	assert host.get(mut vm, key)!.number == 42
	assert host.internal_define_own_property(key, PropertyDescriptor{ value: Value.from_i32(7) })
	last := host.internal_get_own_property(key)?
	assert last.value?.number == 7 && !last.writable?
	assert !last.enumerable? && last.configurable?
	assert host.own_property_keys().len == 1
}

fn test_nonconfigurable_accessors_compare_function_identity_and_reject_kind_changes() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut state := &AccessorState{
		value: Value.from_i32(42)
	}
	mut host := accessor_host(mut vm, mut state)
	key := PropertyName.from_str('value')
	assert host.internal_define_own_property(key, PropertyDescriptor{ configurable: false })
	current := host.internal_get_own_property(key)?
	assert is_compatible_property_descriptor(false, PropertyDescriptor{}, current)
	assert host.internal_define_own_property(key, PropertyDescriptor{ getter: current.getter? })
	assert host.internal_define_own_property(key, PropertyDescriptor{ setter: current.setter? })
	for replacement in [PropertyDescriptor{ getter: js_undefined() },
		PropertyDescriptor{ setter: js_undefined() }, PropertyDescriptor{ value: js_undefined() },
		PropertyDescriptor{ writable: false }, PropertyDescriptor{ configurable: true },
		PropertyDescriptor{ enumerable: false }] {
		assert !is_compatible_property_descriptor(true, replacement, current)
		assert !host.internal_define_own_property(key, replacement)
	}
	assert !host.internal_delete(key)
	assert host.get(mut vm, key)!.number == 42
	assert !is_compatible_property_descriptor(false, PropertyDescriptor{}, none)
	assert is_compatible_property_descriptor(true, PropertyDescriptor{}, none)
}

fn test_freezing_accessors_preserves_setters_and_descriptor_completion_defaults() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut state := &AccessorState{
		value: Value.from_i32(41)
	}
	mut host := accessor_host(mut vm, mut state)
	assert host.set_integrity_level(mut vm, .frozen)!
	assert host.test_integrity_level(.frozen)
	host.set(mut vm, PropertyName.from_str('value'), Value.from_i32(42), .yes)!
	assert host.get(mut vm, PropertyName.from_str('value'))!.number == 42
	assert host.internal_get_own_property(PropertyName.from_str('value'))?.is_accessor_descriptor()
	mut generic := PropertyDescriptor{}
	assert generic.is_empty() && generic.is_generic_descriptor()
	generic.complete()
	assert generic.is_data_descriptor() && generic.value?.is_undefined()
	assert !generic.writable? && generic.attributes() == 0
	mut accessor := PropertyDescriptor{
		setter:     js_undefined()
		enumerable: true
	}
	accessor.complete()
	assert accessor.getter?.is_undefined() && accessor.setter?.is_undefined()
	assert accessor.value == none && accessor.writable == none
	assert !accessor.configurable? && accessor.attributes() == attribute_enumerable
}

fn execute_accessor_source(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'accessors.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 10000 })
}

fn test_compiled_accessor_assignments_updates_and_short_circuit_order() {
	for source, expected in {
		'host.value=42;':         ['set']
		'host.value+=1;':         ['get', 'set']
		'++host.value;':          ['get', 'set']
		'host.value++;':          ['get', 'set']
		'host.value&&=42;':       ['get', 'set']
		'host.value||=42;':       ['get']
		'host.value NULLISH=42;': ['get']
		'"value" in host;':       []string{}
		'delete host.value;':     []string{}
	} {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		mut state := &AccessorState{
			value: Value.from_i32(41)
		}
		host := accessor_host(mut vm, mut state)
		mut global := vm.get_global_object()
		global.create_data_property(PropertyName.from_str('host'), Value.from_object(host))
		result := execute_accessor_source(mut vm, source.replace('NULLISH', '?'.repeat(2)))!
		assert state.events == expected, source
		if expected.len == 2 || source == 'host.value=42;' {
			assert state.value.number == 42
			assert result.number == if source == 'host.value++;' {
				41
			} else {
				42
			}
		}
		for receiver in state.receivers {
			assert receiver.as_object() == host
		}
	}
}

fn test_accessor_abrupt_completions_stop_later_effects_and_restore_execution_frames() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut state := &AccessorState{
		value:     Value.from_i32(41)
		throw_get: true
	}
	host := accessor_host(mut vm, mut state)
	mut global := vm.get_global_object()
	global.create_data_property(PropertyName.from_str('host'), Value.from_object(host))
	for source in ['host.value;', 'host.value+=(globalThis.sideEffect=1);', 'host.value++;',
		'host.value||=(globalThis.sideEffect=1);'] {
		if _ := execute_accessor_source(mut vm, source) {
			assert false
		} else {
			assert thrown_value(err).number == 17
		}
		assert !global.has_own_property(PropertyName.from_str('sideEffect'))
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
	assert state.events == ['get', 'get', 'get', 'get']
	state.throw_get = false
	state.throw_set = true
	if _ := execute_accessor_source(mut vm, 'host.value=42; globalThis.sideEffect=1;') {
		assert false
	} else {
		assert thrown_value(err).number == 23
	}
	assert state.value.number == 41
	assert !global.has_own_property(PropertyName.from_str('sideEffect'))
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	assert execute_accessor_source(mut vm, 'host.value;')!.number == 41
}

fn test_accessor_lookup_propagates_through_coercion_bindings_and_unscopables() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut state := &AccessorState{
		value:     Value.from_i32(41)
		throw_get: true
	}
	mut host := accessor_host(mut vm, mut state)
	getter := host.internal_get_own_property(PropertyName.from_str('value'))?.getter?
	assert host.internal_define_own_property(PropertyName.from_str('valueOf'), PropertyDescriptor{
		getter: getter
	})
	if _ := Value.from_object(host).to_number(mut vm) {
		assert false
	} else {
		assert thrown_value(err).number == 17
	}
	mut environment := ObjectEnvironment.create(host, false, none)
	if _ := environment.get_binding_value(mut vm, utf16_string('value'), false) {
		assert false
	} else {
		assert thrown_value(err).number == 17
	}
	// Getter failure should not affect an ordinary setter.
	environment.set_mutable_binding(mut vm, utf16_string('value'), Value.from_i32(42), true)!
	assert state.value.number == 42
	assert host.internal_define_own_property(PropertyName.from_symbol(vm.well_known_symbol_unscopables()), PropertyDescriptor{
		getter: getter
	})
	with_environment := ObjectEnvironment.create(host, true, none)
	if _, _ := with_environment.has_binding(mut vm, utf16_string('value')) {
		assert false
	} else {
		assert thrown_value(err).number == 17
	}
	// Embedding error diagnostics must not invoke a user-installed message getter.
	mut error_object := create_error(mut vm, vm.realm(), .type_error, utf16_string('original'))
	assert error_object.internal_define_own_property(PropertyName.from_str('message'), PropertyDescriptor{
		getter: getter
	})
	count := state.events.len
	assert error_object.error_message() == none
	assert error_object.get_without_side_effects(PropertyName.from_str('message')).is_accessor()
	assert error_object.get_without_side_effects(PropertyName.from_str('absent')).is_special_empty_value()
	assert state.events.len == count
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
