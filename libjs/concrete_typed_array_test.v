module libjs

fn test_concrete_typed_array_records_preserve_all_kinds_metadata_property_order_and_inheritance() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	object_parent := Object.create(realm, none)
	shared_parent := Object.create(realm, object_parent)
	abstract :=
		TypedArrayConstructor.create(mut vm, realm, shared_parent, PrimitiveObjectPrototypes{})
	for kind in [BufferElementType.big_int64, .big_uint64, .float16, .float32, .float64, .int8,
		.int16, .int32, .uint8, .uint16, .uint32, .uint8_clamped] {
		prototype := ConcreteTypedArrayPrototype.create(mut vm, realm, kind, shared_parent, PrimitiveObjectPrototypes{},
			object_parent)
		getter := fn [prototype] (realm &Realm) &Object {
			return prototype.object
		}
		constructor := ConcreteTypedArrayConstructor.create(mut vm, realm, kind, abstract.object,
			prototype.object, getter)
		assert constructor.kind == kind && prototype.kind == kind
		assert voidptr(prototype.object.prototype?) == voidptr(shared_parent)
		assert voidptr(constructor.object.prototype?) == voidptr(abstract.object)
		mut constructor_names := ['prototype', 'BYTES_PER_ELEMENT', 'length']
		mut prototype_names := ['BYTES_PER_ELEMENT']
		if kind == .uint8 {
			constructor_names << ['fromBase64', 'fromHex']
			prototype_names << ['setFromBase64', 'setFromHex', 'toBase64', 'toHex']
		}
		constructor_names << 'name'
		prototype_names << 'constructor'
		assert constructor.object.own_property_keys() == constructor_names.map(PropertyName.from_str(it))
		assert prototype.object.own_property_keys() == prototype_names.map(PropertyName.from_str(it))
		for object in [prototype.object, constructor.object] {
			bytes := object.internal_get_own_property(PropertyName.from_str('BYTES_PER_ELEMENT'))?
			assert bytes.value?.number == f64(kind.size())
			assert !bytes.writable? && !bytes.enumerable? && !bytes.configurable?
		}
		length := constructor.object.internal_get_own_property(PropertyName.from_str('length'))?
		assert length.value?.number == 3 && length.configurable? && !length.writable?
			&& !length.enumerable?
		name := constructor.object.internal_get_own_property(PropertyName.from_str('name'))?
		assert name.value?.as_string().str() == kind.typed_array_name()
		assert name.configurable? && !name.writable? && !name.enumerable?
		own_parent :=
			constructor.object.internal_get_own_property(PropertyName.from_str('prototype'))?
		assert voidptr(own_parent.value?.as_object()) == voidptr(prototype.object)
		assert !own_parent.configurable? && !own_parent.enumerable? && !own_parent.writable?
		back_reference :=
			prototype.object.internal_get_own_property(PropertyName.from_str('constructor'))?
		assert voidptr(back_reference.value?.as_object()) == voidptr(constructor.object)
		assert back_reference.writable? && back_reference.configurable?
			&& !back_reference.enumerable?
		for inherited in ['from', 'of'] {
			assert same_value(constructor.object.get(mut vm, PropertyName.from_str(inherited))!, abstract.object.get(mut vm,
				PropertyName.from_str(inherited))!)
		}
		assert constructor.object.internal_get_own_property(PropertyName.from_str('from')) == none
		assert Value.from_object(constructor.object).is_constructor()
		array := construct(mut vm, Value.from_object(constructor.object), [
			Value.from_i32(2),
		], none)!.typed_array?
		assert array.kind == kind && array.array_length.length() == 2
		assert voidptr(array.object.prototype?) == voidptr(prototype.object)
		if _ := call(mut vm, Value.from_object(constructor.object), js_undefined(), []Value{}) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == "${kind.typed_array_name()} constructor must be called with 'new'"
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_concrete_typed_array_of_and_species_use_the_real_constructor_receiver_for_every_kind() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	parent := Object.create(realm, none)
	abstract := TypedArrayConstructor.create(mut vm, realm, parent, PrimitiveObjectPrototypes{})
	for kind in [BufferElementType.big_int64, .big_uint64, .float16, .float32, .float64, .int8,
		.int16, .int32, .uint8, .uint16, .uint32, .uint8_clamped] {
		prototype := ConcreteTypedArrayPrototype.create(mut vm, realm, kind, parent, PrimitiveObjectPrototypes{},
			parent)
		getter := fn [prototype] (realm &Realm) &Object {
			return prototype.object
		}
		constructor := ConcreteTypedArrayConstructor.create(mut vm, realm, kind, abstract.object,
			prototype.object, getter)
		species := constructor.object.get(mut vm,
			PropertyName.from_symbol(vm.well_known_symbol_species()))!
		assert same_value(species, Value.from_object(constructor.object))
		method := constructor.object.get(mut vm, PropertyName.from_str('of'))!
		value := if kind.is_bigint() {
			Value.from_bigint(string_to_bigint(utf16_string('42')) or { panic('invalid BigInt literal') })
		} else {
			Value.from_i32(42)
		}
		array := call(mut vm, method, Value.from_object(constructor.object), [value])!.as_object().typed_array?
		assert array.kind == kind && array.array_length.length() == 1
		assert same_value(array.get_value_from_buffer(mut vm, 0, .unordered, true), value)
	}
}

fn test_uint8_array_helper_initialization_preserves_all_six_function_descriptors_and_executes_real_bodies() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	parent := Object.create(realm, none)
	abstract := TypedArrayConstructor.create(mut vm, realm, parent, PrimitiveObjectPrototypes{})
	prototype := ConcreteTypedArrayPrototype.create(mut vm, realm, .uint8, parent, PrimitiveObjectPrototypes{},
		parent)
	getter := fn [prototype] (realm &Realm) &Object {
		return prototype.object
	}
	constructor := ConcreteTypedArrayConstructor.create(mut vm, realm, .uint8, abstract.object,
		prototype.object, getter)
	for name in ['fromBase64', 'fromHex', 'setFromBase64', 'setFromHex', 'toBase64', 'toHex'] {
		object := if name.starts_with('from') { constructor.object } else { prototype.object }
		descriptor := object.internal_get_own_property(PropertyName.from_str(name))?
		assert descriptor.writable? && descriptor.configurable? && !descriptor.enumerable?
		function := descriptor.value?
		assert function.is_function() && !function.is_constructor()
		assert voidptr(function.as_object().prototype?) == voidptr(realm.function_prototype_record())
		assert function.as_object().get_without_side_effects(PropertyName.from_str('name')).as_string().str() == name
		assert function.as_object().get_without_side_effects(PropertyName.from_str('length')).number == if name.starts_with('to') {
			0.0
		} else {
			1.0
		}
	}
	from_hex := constructor.object.get(mut vm, PropertyName.from_str('fromHex'))!
	bytes := call(mut vm, from_hex, js_undefined(), [
		Value.from_string(vm.create_string_from_str('2a00ff')),
	])!
	assert voidptr(bytes.as_object().prototype?) == voidptr(prototype.object)
	to_base64 := bytes.as_object().get(mut vm, PropertyName.from_str('toBase64'))!
	assert call(mut vm, to_base64, bytes, []Value{})!.as_string().str() == 'KgD/'
	set_base64 := bytes.as_object().get(mut vm, PropertyName.from_str('setFromBase64'))!
	result := call(mut vm, set_base64, bytes, [
		Value.from_string(vm.create_string_from_str('Zm9v')),
	])!.as_object()
	assert result.get(mut vm, PropertyName.from_str('written'))!.number == 3
	to_hex := bytes.as_object().get(mut vm, PropertyName.from_str('toHex'))!
	assert call(mut vm, to_hex, bytes, []Value{})!.as_string().str() == '666f6f'
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
