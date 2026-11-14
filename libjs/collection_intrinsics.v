module libjs

import math

// Intrinsics.cpp / ArrayConstructor.cpp: install the ordinary collection
// graph once per realm. The individual String algorithms retain their source
// translations; their implicit Array dependencies now point to this graph.
fn initialize_collection_intrinsics(mut vm VM, mut realm Realm) ! {
	mut array := ArrayObject.create(mut vm, &realm, 0, realm.object_prototype_record())!.object
	realm.array_prototype = array
	for name, behaviour in {
		'indexOf': NativeFunctionPointer(array_prototype_index_of)
		'join': array_prototype_join
		'push': array_prototype_push
		'pop': array_prototype_pop
		'unshift': array_prototype_unshift
		'slice': array_prototype_slice
		'splice': array_prototype_splice
		'forEach': array_prototype_for_each
	} { install_intrinsic_method(mut vm, mut array, name, if name in ['slice','splice'] { 2 } else if name in ['join','pop'] { 0 } else { 1 }, behaviour) }
	install_intrinsic_method(mut vm, mut array, 'toString', 0, fn (mut vm VM) !Value {
		object := vm.this_value().to_object_with_prototypes(mut vm, realm_primitive_prototypes())!
		join := object.get(mut vm, PropertyName.from_str('join'))!
		if join.is_function() { return call(mut vm, join, Value.from_object(object), []) }
		return object_prototype_to_string(mut vm, realm_primitive_prototypes())
	})
	constructor := NativeFunction.create_constructor(mut vm, &realm, realm.function_prototype,
		array_constructor_call, fn (mut vm VM, _ &Object) !&Object {
			return array_constructor_call(mut vm)!.as_object()
		}, 1, PropertyName.from_str('Array'))
	mut array_constructor := constructor.object
	array_constructor.define_direct_property(PropertyName.from_str('prototype'), Value.from_object(array), 0)
	array.define_direct_property(PropertyName.from_str('constructor'), Value.from_object(array_constructor), attribute_writable | attribute_configurable)
	install_intrinsic_method(mut vm, mut array_constructor, 'isArray', 1, fn (mut vm VM) !Value {
		return Value.from_bool(vm.argument(0).is_array(mut vm)!)
	})
	realm.array_constructor = array_constructor
	mut text := StringObject.create(&realm, vm.empty_string(), realm.object_prototype_record()).object
	realm.string_prototype = text
	for name, behaviour in {
		'toString': NativeFunctionPointer(string_prototype_to_string)
		'valueOf': string_prototype_value_of
		'charAt': string_prototype_char_at
		'charCodeAt': string_prototype_char_code_at
		'indexOf': string_prototype_index_of
		'lastIndexOf': string_prototype_last_index_of
		'slice': string_prototype_slice
		'substring': string_prototype_substring
		'substr': string_prototype_substr
		'toLowerCase': string_prototype_to_lowercase
		'toUpperCase': string_prototype_to_uppercase
		'replace': string_prototype_replace
	} { install_intrinsic_method(mut vm, mut text, name, if name in ['toString','valueOf','toLowerCase','toUpperCase'] { 0 } else if name in ['slice','substring','substr','replace'] { 2 } else { 1 }, behaviour) }
	install_intrinsic_method(mut vm, mut text, 'split', 2, fn (mut vm VM) !Value { return string_prototype_split(mut vm, vm.realm().array_prototype_record()) })
	string_constructor := StringConstructor.create(mut vm, &realm, StringConstructorDependencies{
		prototype: text
		prototype_getter: fn (realm &Realm) &Object { return realm.string_prototype or { panic('String prototype absent') } }
		primitives: realm_primitive_prototypes()
	})
	mut global := realm.global_object_record()
	global.define_direct_property(PropertyName.from_str('Array'), Value.from_object(array_constructor), attribute_writable | attribute_configurable)
	global.define_direct_property(PropertyName.from_str('String'), Value.from_object(string_constructor.object), attribute_writable | attribute_configurable)
}

fn install_intrinsic_method(mut vm VM, mut object Object, name string, length int, behaviour NativeFunctionPointer) {
	method := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, behaviour, f64(length), PropertyName.from_str(name), none)
	object.define_direct_property(PropertyName.from_str(name), Value.from_object(method.object), attribute_writable | attribute_configurable)
}

fn realm_primitive_prototypes() PrimitiveObjectPrototypes {
	return PrimitiveObjectPrototypes{
		string: fn (realm &Realm) &Object { return realm.string_prototype or { panic('String prototype absent') } }
		number: fn (realm &Realm) &Object { return realm.object_prototype_record() }
		bigint: fn (realm &Realm) &Object { return realm.object_prototype_record() }
	}
}

fn array_constructor_call(mut vm VM) !Value {
	realm := vm.realm()
	if vm.argument_count() == 1 && vm.argument(0).is_number() {
		length := vm.argument(0).number
		if length < 0 || length > 0xffffffff || math.trunc(length) != length || math.is_nan(length) {
			return vm.throw_error_type(.range_error, .invalid_length, 'array')
		}
		return Value.from_object(ArrayObject.create(mut vm, realm, u64(length), realm.array_prototype_record())!.object)
	}
	mut values := []Value{}
	for index in 0 .. vm.argument_count() { values << vm.argument(index) }
	return Value.from_object(ArrayObject.create_from(mut vm, realm, values, realm.array_prototype_record())!.object)
}

fn array_index_key(index u64) PropertyName { return PropertyName.from_str(index.str()) }

fn array_receiver(mut vm VM) !(&Object, u64) {
	object := vm.this_value().to_object_with_prototypes(mut vm, realm_primitive_prototypes())!
	return object, length_of_array_like(mut vm, object)!
}

fn relative_array_index(mut vm VM, value Value, length u64) !u64 {
	n := value.to_integer_or_infinity(mut vm)!
	return if n < 0 { u64(math.max(f64(length) + n, 0)) } else { u64(math.min(n, f64(length))) }
}

// ArrayPrototype.cpp algorithms use ordinary Get/HasProperty/Set/Delete so
// borrowed methods preserve live array-like behavior and accessor exceptions.
fn array_prototype_index_of(mut vm VM) !Value {
	object, length := array_receiver(mut vm)!
	if length == 0 { return Value.from_i32(-1) }
	mut index := relative_array_index(mut vm, vm.argument(1), length)!
	search := vm.argument(0)
	for index < length {
		vm.consume_execution_budget()!
		key := array_index_key(index)
		if object.internal_has_property(key) && is_strictly_equal(search, object.get(mut vm, key)!) { return Value.from_f64(f64(index)) }
		index++
	}
	return Value.from_i32(-1)
}

fn array_prototype_join(mut vm VM) !Value {
	object, length := array_receiver(mut vm)!
	identity := voidptr(object)
	if identity in vm.array_join_objects { return Value.from_string(vm.empty_string()) }
	vm.array_join_objects[identity] = true
	defer { vm.array_join_objects.delete(identity) }
	separator := if vm.argument(0).is_undefined() { utf16_string(',') } else { vm.argument(0).to_primitive_string(mut vm)!.utf16 }
	mut parts := []Utf16String{}
	for index := u64(0); index < length; index++ {
		vm.consume_execution_budget()!
		if index > 0 { parts << separator }
		value := object.get(mut vm, array_index_key(index))!
		if !value.is_nullish() { parts << value.to_primitive_string(mut vm)!.utf16 }
	}
	return Value.from_string(vm.create_string(utf16_concat(parts)))
}

fn array_prototype_for_each(mut vm VM) !Value {
	object, length := array_receiver(mut vm)!
	callback := vm.argument(0)
	if !callback.is_function() { return vm.throw_error_type(.type_error, .not_a_function, callback.str()) }
	this_argument := vm.argument(1)
	for index := u64(0); index < length; index++ {
		vm.consume_execution_budget()!
		key := array_index_key(index)
		if object.internal_has_property(key) { call(mut vm, callback, this_argument, [object.get(mut vm, key)!, Value.from_f64(f64(index)), Value.from_object(object)])! }
	}
	return js_undefined()
}

fn array_prototype_push(mut vm VM) !Value {
	mut object, length := array_receiver(mut vm)!
	count := u64(vm.argument_count())
	if length + count > 9007199254740991 { return vm.throw_error(.type_error, 'Array-like length exceeds maximum safe integer') }
	for index in 0 .. vm.argument_count() { object.set(mut vm, array_index_key(length + index), vm.argument(index), .yes)! }
	object.set(mut vm, PropertyName.from_str('length'), Value.from_f64(f64(length + count)), .yes)!
	return Value.from_f64(f64(length + count))
}

fn array_prototype_pop(mut vm VM) !Value {
	mut object, length := array_receiver(mut vm)!
	if length == 0 { object.set(mut vm, PropertyName.from_str('length'), Value.from_i32(0), .yes)!; return js_undefined() }
	key := array_index_key(length - 1)
	value := object.get(mut vm, key)!
	object.delete_property_or_throw(mut vm, key)!
	object.set(mut vm, PropertyName.from_str('length'), Value.from_f64(f64(length - 1)), .yes)!
	return value
}

fn array_prototype_unshift(mut vm VM) !Value {
	mut object, length := array_receiver(mut vm)!
	count := u64(vm.argument_count())
	if length + count > 9007199254740991 { return vm.throw_error(.type_error, 'Array-like length exceeds maximum safe integer') }
	if count > 0 {
		for index := length; index > 0; index-- {
			vm.consume_execution_budget()!
			from := array_index_key(index - 1)
			to := array_index_key(index + count - 1)
			if object.internal_has_property(from) { object.set(mut vm, to, object.get(mut vm, from)!, .yes)! } else { object.delete_property_or_throw(mut vm, to)! }
		}
		for index in 0 .. vm.argument_count() { object.set(mut vm, array_index_key(index), vm.argument(index), .yes)! }
	}
	object.set(mut vm, PropertyName.from_str('length'), Value.from_f64(f64(length + count)), .yes)!
	return Value.from_f64(f64(length + count))
}

fn array_species_create(mut vm VM, original &Object, length u64) !&Object {
	mut constructor := js_undefined()
	if original.array_object != none {
		constructor = original.get(mut vm, PropertyName.from_str('constructor'))!
		if constructor.is_object() {
			constructor = constructor.as_object().get(mut vm, PropertyName.from_symbol(vm.well_known_symbol_species()))!
			if constructor.is_null() { constructor = js_undefined() }
		}
	}
	if constructor.is_undefined() { return ArrayObject.create(mut vm, vm.realm(), length, vm.realm().array_prototype_record())!.object }
	return construct(mut vm, constructor, [Value.from_f64(f64(length))], none)
}

fn array_prototype_slice(mut vm VM) !Value {
	object, length := array_receiver(mut vm)!
	start := relative_array_index(mut vm, vm.argument(0), length)!
	end := if vm.argument(1).is_undefined() { length } else { relative_array_index(mut vm, vm.argument(1), length)! }
	count := if end > start { end - start } else { u64(0) }
	mut result := array_species_create(mut vm, object, count)!
	for index := u64(0); index < count; index++ {
		vm.consume_execution_budget()!
		from := array_index_key(start + index)
		if object.internal_has_property(from) { result.create_data_property_or_throw(mut vm, array_index_key(index), object.get(mut vm, from)!)! }
	}
	result.set(mut vm, PropertyName.from_str('length'), Value.from_f64(f64(count)), .yes)!
	return Value.from_object(result)
}

fn array_prototype_splice(mut vm VM) !Value {
	mut object, length := array_receiver(mut vm)!
	start := relative_array_index(mut vm, vm.argument(0), length)!
	insert_count := u64(if vm.argument_count() > 2 { vm.argument_count() - 2 } else { 0 })
	deleted := if vm.argument_count() == 0 { u64(0) } else if vm.argument_count() == 1 { length - start } else { u64(math.min(math.max(vm.argument(1).to_integer_or_infinity(mut vm)!, 0), f64(length - start))) }
	if length + insert_count - deleted > 9007199254740991 { return vm.throw_error(.type_error, 'Array-like length exceeds maximum safe integer') }
	mut result := array_species_create(mut vm, object, deleted)!
	for index := u64(0); index < deleted; index++ {
		vm.consume_execution_budget()!
		from := array_index_key(start + index)
		if object.internal_has_property(from) { result.create_data_property_or_throw(mut vm, array_index_key(index), object.get(mut vm, from)!)! }
	}
	result.set(mut vm, PropertyName.from_str('length'), Value.from_f64(f64(deleted)), .yes)!
	if insert_count < deleted {
		for index := start; index < length - deleted; index++ { move_array_property(mut vm, mut object, index + deleted, index + insert_count)! }
		for index := length; index > length - deleted + insert_count; index-- { object.delete_property_or_throw(mut vm, array_index_key(index - 1))! }
	} else if insert_count > deleted {
		for index := length - deleted; index > start; index-- { move_array_property(mut vm, mut object, index + deleted - 1, index + insert_count - 1)! }
	}
	for index := u64(0); index < insert_count; index++ { object.set(mut vm, array_index_key(start + index), vm.argument(u32(index + 2)), .yes)! }
	object.set(mut vm, PropertyName.from_str('length'), Value.from_f64(f64(length - deleted + insert_count)), .yes)!
	return Value.from_object(result)
}

fn move_array_property(mut vm VM, mut object Object, from u64, to u64) ! {
	vm.consume_execution_budget()!
	key := array_index_key(from)
	if object.internal_has_property(key) { object.set(mut vm, array_index_key(to), object.get(mut vm, key)!, .yes)! } else { object.delete_property_or_throw(mut vm, array_index_key(to))! }
}
