module libjs

fn typed_prototype_fixture(mut vm VM, realm &Realm, parent &Object, array_parent &Object) &TypedArrayPrototype {
	iterator := ArrayIteratorPrototype.create(mut vm, realm, parent, array_parent, parent)
	getter := fn [parent] (realm &Realm) &Object {
		return parent
	}
	constructor := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype, fn (mut vm VM) !Value {
		return js_undefined()
	}, fn (mut vm VM, target &Object) !&Object {
		panic('fixture constructor not requested')
	}, 1, PropertyName.from_str('Host'))
	return TypedArrayPrototype.create(mut vm, realm, parent, TypedArrayPrototypeDependencies{
		primitives:         PrimitiveObjectPrototypes{
			number: getter
			bigint: getter
			string: getter
		}
		constructor_getter: fn [constructor] (realm &Realm, kind BufferElementType) &Object {
			return constructor.object
		}
		prototype_getter:   fn [parent] (realm &Realm, kind BufferElementType) &Object {
			return parent
		}
		iterator_prototype: iterator.object
		array_prototype:    array_parent
	})
}

fn test_typed_array_prototype_initialization_preserves_source_property_order_metadata_and_intrinsic_identities() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	parent := Object.create(realm, none)
	mut array_parent := Object.create(realm, parent)
	shared_string := NativeFunction.create(mut vm, realm, realm.function_prototype, fn (mut vm VM) !Value {
		return Value.from_i32(42)
	}, 0, PropertyName.from_str('toString'), none)
	array_parent.define_direct_property(PropertyName.from_str('toString'),
		Value.from_object(shared_string.object), 5)
	prototype := typed_prototype_fixture(mut vm, realm, parent, array_parent)
	assert voidptr(prototype.object.prototype?) == voidptr(parent)
	names := ['buffer', 'byteLength', 'byteOffset', 'length', 'at', 'copyWithin', 'entries', 'every',
		'fill', 'filter', 'find', 'findIndex', 'findLast', 'findLastIndex', 'forEach', 'includes',
		'indexOf', 'join', 'keys', 'lastIndexOf', 'map', 'reduce', 'reduceRight', 'reverse', 'set',
		'slice', 'some', 'sort', 'subarray', 'toLocaleString', 'toReversed', 'toSorted', 'with',
		'values', 'toString']
	mut expected := names.map(PropertyName.from_str(it))
	expected << PropertyName.from_symbol(vm.well_known_symbol_to_string_tag())
	expected << PropertyName.from_symbol(vm.well_known_symbol_iterator())
	assert prototype.object.own_property_keys() == expected
	for name in names {
		property := prototype.object.internal_get_own_property(PropertyName.from_str(name))?
		assert !property.enumerable? && property.configurable?
		if name in ['buffer', 'byteLength', 'byteOffset', 'length'] {
			assert property.is_accessor_descriptor() && property.setter?.is_undefined()
			getter := property.getter?.as_object()
			assert getter.get_without_side_effects(PropertyName.from_str('name')).as_string().str() == 'get ${name}'
			assert getter.get_without_side_effects(PropertyName.from_str('length')).number == 0
		} else {
			assert property.writable? && property.is_data_descriptor()
			function := property.value?.as_object()
			assert voidptr(function.prototype?) == voidptr(realm.function_prototype_record())
			assert !Value.from_object(function).is_constructor()
			length := match name {
				'copyWithin', 'slice', 'subarray', 'with' { 2 }
				'entries', 'keys', 'reverse', 'toLocaleString', 'toReversed', 'values', 'toString' { 0 }
				else { 1 }
			}

			assert function.get_without_side_effects(PropertyName.from_str('name')).as_string().str() == name
			assert function.get_without_side_effects(PropertyName.from_str('length')).number == length
		}
	}
	to_string := prototype.object.get_without_side_effects(PropertyName.from_str('toString'))
	assert voidptr(to_string.as_object()) == voidptr(shared_string.object)
	values := prototype.object.get_without_side_effects(PropertyName.from_str('values'))
	alias :=
		prototype.object.get_without_side_effects(PropertyName.from_symbol(vm.well_known_symbol_iterator()))
	assert same_value(values, alias)
	mut object := prototype.object
	object.define_direct_property(PropertyName.from_str('values'), Value.from_i32(7), 5)
	assert same_value(object.get_without_side_effects(PropertyName.from_symbol(vm.well_known_symbol_iterator())),
		alias)
}

fn test_typed_array_prototype_shared_to_string_is_generic_while_values_alias_remains_branded() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	mut array_parent := Object.create(vm.realm(), parent)
	fallback := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		return Value.from_string(vm.create_string_from_str('host fallback'))
	}, 0, PropertyName.from_str('toString'), none)
	getter := fn [fallback] (realm &Realm) &Object {
		return fallback.object
	}
	shared_string := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [getter] (mut vm VM) !Value {
		return array_prototype_to_string(mut vm, PrimitiveObjectPrototypes{}, getter)
	}, 0, PropertyName.from_str('toString'), none)
	array_parent.define_direct_property(PropertyName.from_str('toString'),
		Value.from_object(shared_string.object), 5)
	prototype := typed_prototype_fixture(mut vm, vm.realm(), parent, array_parent)
	mut array := TypedArray.create(vm.realm(), .uint8, 3, ArrayBufferObject.create_from_bytes(vm.realm(), [
		u8(1),
		2,
		42,
	], false, parent), prototype.object)
	text := call(mut vm, Value.from_object(shared_string.object), Value.from_object(array.object),
		[]Value{})!
	assert text.as_string().str() == '1,2,42'
	alias :=
		prototype.object.get_without_side_effects(PropertyName.from_symbol(vm.well_known_symbol_iterator()))
	iterator := call(mut vm, alias, Value.from_object(array.object), []Value{})!.as_object()
	mut record := get_iterator_direct(mut vm, iterator)!
	values := iterator_to_list(mut vm, mut record)!
	assert values.map(it.number) == [f64(1), 2, 42]
	mut generic := Object.create(vm.realm(), prototype.object)
	join := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [generic] (mut vm VM) !Value {
		assert voidptr(vm.this_value().as_object()) == voidptr(generic) && vm.argument_count() == 0
		return Value.from_i32(99)
	}, 0, PropertyName.from_str('join'), none)
	generic.define_direct_property(PropertyName.from_str('join'), Value.from_object(join.object), 7)
	result := call(mut vm, Value.from_object(shared_string.object), Value.from_object(generic),
		[]Value{})!
	assert result.number == 99
	if _ := call(mut vm, alias, Value.from_object(generic), []Value{}) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()?.str() == 'Not an object of type TypedArray'
	}
	generic.define_direct_property(PropertyName.from_str('join'), Value.from_i32(7), 7)
	result_fallback := call(mut vm, Value.from_object(shared_string.object),
		Value.from_object(generic), []Value{})!
	assert result_fallback.as_string().str() == 'host fallback'
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
