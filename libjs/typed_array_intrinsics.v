// SPDX-License-Identifier: BSD-2-Clause
module libjs

import platform

fn realm_typed_array_constructor(realm &Realm, kind BufferElementType) &Object {
	return realm.typed_array_constructors[kind] or { panic('Missing ' + kind.typed_array_name() + ' constructor') }
}

fn realm_typed_array_prototype(realm &Realm, kind BufferElementType) &Object {
	return realm.typed_array_prototypes[kind] or { panic('Missing ' + kind.typed_array_name() + ' prototype') }
}

// Static functions supply GetPrototypeFromConstructor's one-argument fallback
// without capturing a realm or registering a new closure for each allocation.
fn typed_array_intrinsic_prototype_getter(kind BufferElementType) IntrinsicPrototypeGetter {
	return match kind {
		.big_int64 { fn (realm &Realm) &Object { return realm_typed_array_prototype(realm, .big_int64) } }
		.big_uint64 { fn (realm &Realm) &Object { return realm_typed_array_prototype(realm, .big_uint64) } }
		.float16 { fn (realm &Realm) &Object { return realm_typed_array_prototype(realm, .float16) } }
		.float32 { fn (realm &Realm) &Object { return realm_typed_array_prototype(realm, .float32) } }
		.float64 { fn (realm &Realm) &Object { return realm_typed_array_prototype(realm, .float64) } }
		.int8 { fn (realm &Realm) &Object { return realm_typed_array_prototype(realm, .int8) } }
		.int16 { fn (realm &Realm) &Object { return realm_typed_array_prototype(realm, .int16) } }
		.int32 { fn (realm &Realm) &Object { return realm_typed_array_prototype(realm, .int32) } }
		.uint8 { fn (realm &Realm) &Object { return realm_typed_array_prototype(realm, .uint8) } }
		.uint16 { fn (realm &Realm) &Object { return realm_typed_array_prototype(realm, .uint16) } }
		.uint32 { fn (realm &Realm) &Object { return realm_typed_array_prototype(realm, .uint32) } }
		.uint8_clamped { fn (realm &Realm) &Object { return realm_typed_array_prototype(realm, .uint8_clamped) } }
	}
}

fn realm_typed_array_dependencies(realm &Realm) TypedArrayPrototypeDependencies {
	return TypedArrayPrototypeDependencies{
		primitives: realm_primitive_prototypes()
		constructor_getter: realm_typed_array_constructor
		prototype_getter: realm_typed_array_prototype
		iterator_prototype: realm.array_iterator_prototype or { panic('Missing Array iterator prototype') }
		array_prototype: realm.array_prototype_record()
	}
}

fn typed_array_intrinsic_operation(mut vm VM) !string {
	function := vm.running_execution_context().function or { return vm.throw_error(.internal_error, 'Missing typed-array callee') }
	// This is the native record's immutable initial name, independent of the
	// author-visible configurable .name property and of a bound/proxy caller.
	match function {
		NativeFunction { return function.name.str() }
		else { return vm.throw_error(.internal_error, 'Invalid typed-array intrinsic callee') }
	}
}

fn typed_array_intrinsic_method(mut vm VM) !Value {
	name := typed_array_intrinsic_operation(mut vm)!
	return typed_array_prototype_dispatch(mut vm, if name.starts_with('get ') { name[4..] } else { name }, realm_typed_array_dependencies(vm.realm()))
}

fn typed_array_intrinsic_from(mut vm VM) !Value { return typed_array_constructor_from(mut vm, realm_primitive_prototypes()) }

fn uint8_array_intrinsic_method(mut vm VM) !Value {
	name := typed_array_intrinsic_operation(mut vm)!
	primitive := realm_primitive_prototypes()
	return match name {
		'fromBase64' { uint8_array_constructor_from_base64(mut vm, typed_array_intrinsic_prototype_getter(.uint8))! }
		'fromHex' { uint8_array_constructor_from_hex(mut vm, typed_array_intrinsic_prototype_getter(.uint8))! }
		'setFromBase64' { uint8_array_prototype_set_from_base64(mut vm, primitive, vm.realm().object_prototype_record())! }
		'setFromHex' { uint8_array_prototype_set_from_hex(mut vm, primitive, vm.realm().object_prototype_record())! }
		'toBase64' { uint8_array_prototype_to_base64(mut vm, primitive)! }
		'toHex' { uint8_array_prototype_to_hex(mut vm, primitive)! }
		else { return vm.throw_error(.internal_error, 'Unknown Uint8Array intrinsic operation') }
	}
}

fn initialize_typed_array_intrinsics(mut vm VM, mut realm Realm) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut prototype := create_typed_array_prototype(mut vm, realm, realm.object_prototype, realm_typed_array_dependencies(realm), true).object
	realm.typed_array_prototype = prototype
	mut constructor := NativeFunction.create_constructor_record(mut vm, realm, realm.function_prototype, typed_array_constructor_call, typed_array_constructor_construct, PropertyName.from_str('TypedArray')).object
	realm.typed_array_constructor = constructor
	constructor.define_direct_property(PropertyName.from_str('prototype'), Value.from_object(prototype), 0)
	constructor.set_function_length(0)
	constructor.set_function_name(mut vm, PropertyName.from_str('TypedArray'), none)
	prototype.define_direct_property(PropertyName.from_str('constructor'), Value.from_object(constructor), attribute_writable | attribute_configurable)
	install_intrinsic_method(mut vm, realm, mut constructor, 'from', 1, typed_array_intrinsic_from)
	install_intrinsic_method(mut vm, realm, mut constructor, 'of', 0, typed_array_constructor_of)
	constructor.define_native_accessor(mut vm, realm, PropertyName.from_symbol(vm.well_known_symbol_species()), typed_array_constructor_species_getter, unsafe { nil }, attribute_configurable, realm.function_prototype)
	for kind in [BufferElementType.big_int64, .big_uint64, .float16, .float32, .float64, .int8, .int16, .int32, .uint8, .uint16, .uint32, .uint8_clamped] {
		mut concrete := Object.create(realm, prototype)
		concrete.define_direct_property(PropertyName.from_str('BYTES_PER_ELEMENT'), Value.from_f64(f64(kind.size())), 0)
		realm.typed_array_prototypes[kind] = concrete
		mut function := create_typed_array_intrinsic_constructor(mut vm, realm, kind, constructor)
		realm.typed_array_constructors[kind] = function
		function.define_direct_property(PropertyName.from_str('prototype'), Value.from_object(concrete), 0)
		function.define_direct_property(PropertyName.from_str('BYTES_PER_ELEMENT'), Value.from_f64(f64(kind.size())), 0)
		concrete.define_direct_property(PropertyName.from_str('constructor'), Value.from_object(function), attribute_writable | attribute_configurable)
		if kind == .uint8 {
			for name in ['fromBase64', 'fromHex'] { install_intrinsic_method(mut vm, realm, mut function, name, 1, uint8_array_intrinsic_method) }
			for name in ['setFromBase64', 'setFromHex', 'toBase64', 'toHex'] { install_intrinsic_method(mut vm, realm, mut concrete, name, if name.starts_with('set') { 1 } else { 0 }, uint8_array_intrinsic_method) }
		}
	}
}
