// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Runtime/ObjectConstructor.{h,cpp}. The iterator-dependent fromEntries and
// groupBy algorithms remain separate slices; the installed methods below use
// the ordinary/exotic object operations rather than a browser-specific shim.
@[heap]
pub struct ObjectConstructor {
pub:
	object &Object
}

pub fn ObjectConstructor.create(mut vm VM, realm &Realm) &ObjectConstructor {
	function := NativeFunction.create_constructor_record(mut vm, realm, realm.function_prototype,
		object_constructor_call, object_constructor_construct, PropertyName.from_str('Object'))
	mut object := function.object
	object.define_direct_property(PropertyName.from_str('prototype'),
		Value.from_object(realm.object_prototype_record()), 0)
	names := ['defineProperty', 'defineProperties', 'is', 'getOwnPropertyDescriptor',
		'getOwnPropertyDescriptors', 'getOwnPropertyNames', 'getOwnPropertySymbols', 'getPrototypeOf',
		'setPrototypeOf', 'isExtensible', 'isFrozen', 'isSealed', 'preventExtensions', 'freeze',
		'seal', 'keys', 'values', 'entries', 'create', 'hasOwn', 'assign']
	lengths := [3, 2, 2, 2, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2]
	behaviours := [NativeFunctionPointer(object_constructor_define_property),
		object_constructor_define_properties, object_constructor_is,
		object_constructor_get_own_property_descriptor,
		object_constructor_get_own_property_descriptors, object_constructor_get_own_property_names,
		object_constructor_get_own_property_symbols, object_constructor_get_prototype_of,
		object_constructor_set_prototype_of, object_constructor_is_extensible,
		object_constructor_is_frozen, object_constructor_is_sealed,
		object_constructor_prevent_extensions, object_constructor_freeze, object_constructor_seal,
		object_constructor_keys, object_constructor_values, object_constructor_entries,
		object_constructor_create, object_constructor_has_own, object_constructor_assign]
	for index, name in names {
		install_intrinsic_method(mut vm, realm, mut object, name, lengths[index], behaviours[index])
	}
	object.set_function_length(1)
	object.set_function_name(mut vm, PropertyName.from_str('Object'), none)
	mut prototype := realm.object_prototype_record()
	prototype.define_direct_property(PropertyName.from_str('constructor'), Value.from_object(object),
		attribute_writable | attribute_configurable)
	return &ObjectConstructor{ object: object }
}

// 20.1.1.1 Object ( [ value ] ). Calling Object has the same value conversion
// as constructing with Object itself as NewTarget.
fn object_constructor_call(mut vm VM) !Value {
	value := vm.argument(0)
	if value.is_nullish() {
		return Value.from_object(Object.create(vm.realm(), vm.realm().object_prototype))
	}
	return Value.from_object(value.to_object_with_prototypes(mut vm, realm_primitive_prototypes())!)
}

fn object_constructor_construct(mut vm VM, new_target &Object) !&Object {
	active := vm.active_function_object() or { panic('Object constructor has no active function') }
	assert active is NativeFunction
	if voidptr(active.object) != voidptr(new_target) {
		prototype := get_prototype_from_constructor(mut vm, new_target, fn (realm &Realm) &Object {
			return realm.object_prototype_record()
		})!
		return Object.create(vm.realm(), prototype)
	}
	return object_constructor_call(mut vm)!.as_object()
}

fn object_constructor_define_property(mut vm VM) !Value {
	value := vm.argument(0)
	if !value.is_object() { return vm.throw_error_type(.type_error, .not_an_object, value.str()) }
	mut object := value.as_object()
	key := vm.argument(1).to_property_key(mut vm)!
	descriptor := to_property_descriptor(mut vm, vm.argument(2))!
	object.define_property_or_throw(mut vm, key, descriptor)!
	return value
}

fn object_constructor_define_properties(mut vm VM) !Value {
	value := vm.argument(0)
	if !value.is_object() { return vm.throw_error_type(.type_error, .not_an_object, value.str()) }
	mut object := value.as_object()
	properties := vm.argument(1).to_object_with_prototypes(mut vm, realm_primitive_prototypes())!
	return Value.from_object(object.define_properties(mut vm, properties)!)
}

fn object_constructor_create(mut vm VM) !Value {
	value := vm.argument(0)
	if !value.is_object() && !value.is_null() {
		return vm.throw_error_type(.type_error, .object_prototype_wrong_type)
	}
	prototype := if value.is_object() { ?&Object(value.as_object()) } else { none }
	mut object := Object.create(vm.realm(), prototype)
	if !vm.argument(1).is_undefined() {
		properties := vm.argument(1).to_object_with_prototypes(mut vm, realm_primitive_prototypes())!
		object.define_properties(mut vm, properties)!
	}
	return Value.from_object(object)
}

fn object_constructor_get_own_property_descriptor(mut vm VM) !Value {
	object := vm.argument(0).to_object_with_prototypes(mut vm, realm_primitive_prototypes())!
	key := vm.argument(1).to_property_key(mut vm)!
	return from_property_descriptor(mut vm, object.internal_get_own_property(key), vm.realm().object_prototype)
}

fn object_constructor_get_own_property_descriptors(mut vm VM) !Value {
	object := vm.argument(0).to_object_with_prototypes(mut vm, realm_primitive_prototypes())!
	mut descriptors := Object.create(vm.realm(), vm.realm().object_prototype)
	for key in object.own_property_keys() {
		vm.consume_execution_budget()!
		descriptor := from_property_descriptor(mut vm, object.internal_get_own_property(key), vm.realm().object_prototype)
		if !descriptor.is_undefined() {
			descriptors.create_data_property_or_throw(mut vm, key, descriptor)!
		}
	}
	return Value.from_object(descriptors)
}

fn object_constructor_get_own_keys(mut vm VM, symbols bool) !Value {
	object := vm.argument(0).to_object_with_prototypes(mut vm, realm_primitive_prototypes())!
	mut keys := []Value{}
	for key in object.own_property_keys() {
		vm.consume_execution_budget()!
		if key.is_symbol() == symbols { keys << key.to_value(mut vm) }
	}
	return Value.from_object(ArrayObject.create_from(mut vm, vm.realm(), keys, vm.realm().array_prototype_record())!.object)
}

fn object_constructor_get_own_property_names(mut vm VM) !Value {
	return object_constructor_get_own_keys(mut vm, false)
}

fn object_constructor_get_own_property_symbols(mut vm VM) !Value {
	return object_constructor_get_own_keys(mut vm, true)
}

fn object_constructor_enumerable_properties(mut vm VM, kind PropertyKind) !Value {
	object := vm.argument(0).to_object_with_prototypes(mut vm, realm_primitive_prototypes())!
	mut values := []Value{}
	for key in object.own_property_keys() {
		vm.consume_execution_budget()!
		if key.is_symbol() { continue }
		descriptor := object.internal_get_own_property(key) or { continue }
		if !(descriptor.enumerable or { false }) { continue }
		name := key.to_value(mut vm)
		if kind == .key {
			values << name
			continue
		}
		value := object.get(mut vm, key)!
		if kind == .value {
			values << value
			continue
		}
		values << Value.from_object(ArrayObject.create_from(mut vm, vm.realm(), [name, value], vm.realm().array_prototype_record())!.object)
	}
	return Value.from_object(ArrayObject.create_from(mut vm, vm.realm(), values, vm.realm().array_prototype_record())!.object)
}

fn object_constructor_keys(mut vm VM) !Value {
	return object_constructor_enumerable_properties(mut vm, .key)
}

fn object_constructor_values(mut vm VM) !Value {
	return object_constructor_enumerable_properties(mut vm, .value)
}

fn object_constructor_entries(mut vm VM) !Value {
	return object_constructor_enumerable_properties(mut vm, .key_and_value)
}

fn object_constructor_assign(mut vm VM) !Value {
	mut target := vm.argument(0).to_object_with_prototypes(mut vm, realm_primitive_prototypes())!
	for index in 1 .. vm.argument_count() {
		vm.consume_execution_budget()!
		value := vm.argument(index)
		if value.is_nullish() { continue }
		source := value.to_object_with_prototypes(mut vm, realm_primitive_prototypes())!
		for key in source.own_property_keys() {
			vm.consume_execution_budget()!
			descriptor := source.internal_get_own_property(key) or { continue }
			if !(descriptor.enumerable or { false }) { continue }
			target.set(mut vm, key, source.get(mut vm, key)!, .yes)!
		}
	}
	return Value.from_object(target)
}

fn object_constructor_get_prototype_of(mut vm VM) !Value {
	object := vm.argument(0).to_object_with_prototypes(mut vm, realm_primitive_prototypes())!
	prototype := object.internal_get_prototype_of() or { return js_null() }
	return Value.from_object(prototype)
}

fn object_constructor_set_prototype_of(mut vm VM) !Value {
	value := vm.argument(0)
	if value.is_nullish() { return vm.throw_error_type(.type_error, .to_object_null_or_undefined) }
	prototype := vm.argument(1)
	if !prototype.is_object() && !prototype.is_null() {
		return vm.throw_error_type(.type_error, .object_prototype_wrong_type)
	}
	if !value.is_object() { return value }
	mut object := value.as_object()
	if !object.internal_set_prototype_of(if prototype.is_object() {
		?&Object(prototype.as_object())
	} else {
		none
	}) {
		return vm.throw_error_type(.type_error, .object_set_prototype_of_returned_false)
	}
	return value
}

fn object_constructor_has_own(mut vm VM) !Value {
	object := vm.argument(0).to_object_with_prototypes(mut vm, realm_primitive_prototypes())!
	key := vm.argument(1).to_property_key(mut vm)!
	return Value.from_bool(object.has_own_property(key))
}

fn object_constructor_is(mut vm VM) !Value {
	return Value.from_bool(same_value(vm.argument(0), vm.argument(1)))
}

fn object_constructor_is_extensible(mut vm VM) !Value {
	value := vm.argument(0)
	return Value.from_bool(value.is_object() && value.as_object().internal_is_extensible())
}

fn object_constructor_is_frozen(mut vm VM) !Value {
	value := vm.argument(0)
	return Value.from_bool(!value.is_object() || value.as_object().test_integrity_level(.frozen))
}

fn object_constructor_is_sealed(mut vm VM) !Value {
	value := vm.argument(0)
	return Value.from_bool(!value.is_object() || value.as_object().test_integrity_level(.sealed))
}

fn object_constructor_prevent_extensions(mut vm VM) !Value {
	value := vm.argument(0)
	if !value.is_object() { return value }
	mut object := value.as_object()
	if !object.internal_prevent_extensions() {
		return vm.throw_error_type(.type_error, .object_prevent_extensions_returned_false)
	}
	return value
}

fn object_constructor_integrity(mut vm VM, level IntegrityLevel) !Value {
	value := vm.argument(0)
	if !value.is_object() { return value }
	mut object := value.as_object()
	if !object.set_integrity_level(mut vm, level)! {
		return vm.throw_error_type(.type_error, if level == .frozen {
			ErrorType.object_freeze_failed
		} else {
			ErrorType.object_seal_failed
		})
	}
	return value
}

fn object_constructor_freeze(mut vm VM) !Value {
	return object_constructor_integrity(mut vm, .frozen)
}

fn object_constructor_seal(mut vm VM) !Value {
	return object_constructor_integrity(mut vm, .sealed)
}
