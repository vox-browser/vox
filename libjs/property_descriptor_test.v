module libjs

@[heap]
struct DescriptorReadState {
mut:
	events  []string
	values  map[string]Value
	fail_at string
}

fn descriptor_read_object(mut vm VM, mut state DescriptorReadState, fields []string) &Object {
	mut object := Object.create(vm.realm(), none)
	for field in fields {
		getter := NativeFunction.create(mut vm, vm.realm(), none, fn [mut state, field] (mut vm VM) !Value {
			state.events << field
			if state.fail_at == field { return throw_completion(Value.from_i32(17)) }
			return state.values[field] or { js_undefined() }
		}, 0, PropertyName.from_str(field), 'get')
		assert object.internal_define_own_property(mut vm, PropertyName.from_str(field), PropertyDescriptor{
			getter: Value.from_object(getter.object)
		}) or { panic(err) }
	}
	return object
}

fn test_to_property_descriptor_reads_inherited_fields_and_preserves_presence() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut parent := Object.create(vm.realm(), none)
	parent.create_data_property(mut vm, PropertyName.from_str('enumerable'), Value.from_i32(1)) or {
		panic(err)
	}
	parent.create_data_property(mut vm, PropertyName.from_str('writable'), Value.from_i32(0)) or {
		panic(err)
	}
	parent.create_data_property(mut vm, PropertyName.from_str('value'), js_undefined()) or {
		panic(err)
	}
	mut object := Object.create(vm.realm(), parent)
	object.create_data_property(mut vm, PropertyName.from_str('configurable'),
		Value.from_object(parent)) or { panic(err) }
	object.create_data_property(mut vm, PropertyName.from_str('ignored'), Value.from_i32(42)) or {
		panic(err)
	}
	descriptor := to_property_descriptor(mut vm, Value.from_object(object))!
	assert descriptor.is_data_descriptor()
	assert descriptor.enumerable? && descriptor.configurable? && !descriptor.writable?
	assert descriptor.value?.is_undefined()
	assert descriptor.getter == none && descriptor.setter == none
	empty := Object.create(vm.realm(), none)
	assert to_property_descriptor(mut vm, Value.from_object(empty))!.is_empty()
}

fn test_descriptor_conversion_preserves_field_order_and_stops_at_abrupt_completion() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	fields := ['enumerable', 'configurable', 'value', 'writable', 'get', 'set']
	for stop in fields {
		mut state := &DescriptorReadState{
			fail_at: stop
		}
		object := descriptor_read_object(mut vm, mut state, fields)
		if _ := to_property_descriptor(mut vm, Value.from_object(object)) {
			assert false
		} else {
			assert thrown_value(err).number == 17
		}
		assert state.events == fields[..fields.index(stop) + 1]
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
	mut state := &DescriptorReadState{}
	object := descriptor_read_object(mut vm, mut state, fields)
	if _ := to_property_descriptor(mut vm, Value.from_object(object)) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()? == ErrorType.accessor_value_or_writable.message()
	}
	assert state.events == fields
}

fn test_descriptor_conversion_rejects_noncallable_getters_before_reading_setters() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for field in ['get', 'set'] {
		for invalid in [js_null(), Value.from_bool(false), Value.from_i32(42),
			Value.from_object(Object.create(vm.realm(), none))] {
			mut state := &DescriptorReadState{
				values: {
					field: invalid
				}
			}
			object := descriptor_read_object(mut vm, mut state, ['get', 'set'])
			if _ := to_property_descriptor(mut vm, Value.from_object(object)) {
				assert false
			} else {
				assert thrown_value(err).as_object().error_kind()? == .type_error
				assert thrown_value(err).as_object().error_message()? == ErrorType.accessor_bad_field.formatted(field)
			}
			assert state.events == if field == 'get' {
				['get']
			} else {
				['get', 'set']
			}
		}
	}
	for invalid in [js_undefined(), js_null(), Value.from_i32(42),
		Value.from_bool(false)] {
		if _ := to_property_descriptor(mut vm, invalid) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
	}
}

fn test_from_property_descriptor_keeps_source_field_order_attributes_and_prototype() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	assert from_property_descriptor(mut vm, none, prototype).is_undefined()
	data := PropertyDescriptor{
		value:        Value.from_i32(42)
		writable:     false
		enumerable:   true
		configurable: false
	}
	data_object := from_property_descriptor(mut vm, data, prototype).as_object()
	assert data_object.internal_get_prototype_of()? == prototype
	mut names := []string{}
	for key in data_object.own_property_keys() {
		names << key.str()
		descriptor := data_object.internal_get_own_property(key)?
		assert descriptor.writable? && descriptor.enumerable? && descriptor.configurable?
	}
	assert names == ['value', 'writable', 'enumerable', 'configurable']
	assert data_object.get(mut vm, PropertyName.from_str('value'))!.number == 42
	assert !data_object.get(mut vm, PropertyName.from_str('writable'))!.to_boolean()
	getter := NativeFunction.create(mut vm, vm.realm(), none, fn (mut vm VM) !Value {
		return Value.from_i32(42)
	}, 0, PropertyName.from_str('answer'), 'get')
	accessor := PropertyDescriptor{
		getter:       Value.from_object(getter.object)
		setter:       js_undefined()
		configurable: true
	}
	accessor_object := from_property_descriptor(mut vm, accessor, prototype).as_object()
	names.clear()
	for key in accessor_object.own_property_keys() {
		names << key.str()
	}
	assert names == ['get', 'set', 'configurable']
	roundtrip := to_property_descriptor(mut vm, Value.from_object(accessor_object))!
	assert same_value(roundtrip.getter?, accessor.getter?)
	assert roundtrip.setter?.is_undefined() && roundtrip.configurable?
	assert roundtrip.value == none && roundtrip.writable == none && roundtrip.enumerable == none
}
