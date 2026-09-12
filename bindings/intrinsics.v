// Copyright (c) 2022-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Bindings/Intrinsics.{h,cpp}. Generated LibJS prototype
// classes are represented by stable named objects; lazy creation and identity
// caching match the upstream ownership and lookup behavior.
module bindings

import dom
import html

pub enum IntrinsicObjectKind {
	namespace_
	prototype
	constructor
}

@[heap]
pub struct IntrinsicObject {
pub:
	name string
	kind IntrinsicObjectKind
}

pub enum UnforgeableFunctionType {
	setter
	getter
}

pub struct UnforgeableKey {
pub:
	interface_name string
	attribute_name string
	type_          UnforgeableFunctionType
}

fn (key UnforgeableKey) cache_key() string {
	return '${key.interface_name}\x00${key.attribute_name}\x00${int(key.type_)}'
}

pub type NativeFunctionBehavior = fn ([]dom.JSValue) !dom.JSValue

@[heap]
pub struct NativeFunction {
pub:
	name     string
	length   int
	prefix   string
	behavior NativeFunctionBehavior @[required]
}

pub fn (function &NativeFunction) call(arguments []dom.JSValue) !dom.JSValue {
	return function.behavior(arguments)
}

@[heap]
pub struct Intrinsics {
pub:
	realm &html.ScriptingRealm
mut:
	namespaces                   map[string]&IntrinsicObject
	prototypes                   map[string]&InterfacePrototypeObject
	constructors                 map[string]&InterfaceConstructor
	unforgeable_function_indices map[string]int
	unforgeable_functions        []&NativeFunction
}

pub fn Intrinsics.create(realm &html.ScriptingRealm) &Intrinsics {
	return &Intrinsics{
		realm: realm
	}
}

pub fn (mut intrinsics Intrinsics) ensure_web_namespace(namespace_name string) &IntrinsicObject {
	if namespace_ := intrinsics.namespaces[namespace_name] {
		return namespace_
	}
	namespace_ := &IntrinsicObject{
		name: namespace_name
		kind: .namespace_
	}
	intrinsics.namespaces[namespace_name] = namespace_
	return namespace_
}

pub fn (mut intrinsics Intrinsics) ensure_web_prototype(class_name string) &InterfacePrototypeObject {
	if prototype := intrinsics.prototypes[class_name] {
		return prototype
	}
	return intrinsics.create_web_prototype_and_constructor(InterfaceObjectMetadata.create(class_name))
}

pub fn (mut intrinsics Intrinsics) ensure_web_prototype_with_metadata(metadata InterfaceObjectMetadata) &InterfacePrototypeObject {
	key := metadata.utf16_namespaced_name
	if prototype := intrinsics.prototypes[key] {
		return prototype
	}
	return intrinsics.create_web_prototype_and_constructor(metadata)
}

pub fn (mut intrinsics Intrinsics) ensure_web_constructor(class_name string) &InterfaceConstructor {
	if constructor := intrinsics.constructors[class_name] {
		return constructor
	}
	_ = intrinsics.ensure_web_prototype(class_name)
	return intrinsics.constructors[class_name] or { panic('interface constructor was not created') }
}

pub fn (intrinsics &Intrinsics) existing_web_prototype(class_name string) &InterfacePrototypeObject {
	return intrinsics.prototypes[class_name] or { panic('interface prototype was not created') }
}

pub fn (mut intrinsics Intrinsics) create_web_prototype_and_constructor(metadata InterfaceObjectMetadata) &InterfacePrototypeObject {
	key := metadata.utf16_namespaced_name
	prototype := InterfacePrototypeObject.create(intrinsics.realm, metadata)
	intrinsics.prototypes[key] = prototype
	mut mutable_prototype := unsafe { &InterfacePrototypeObject(prototype) }
	mutable_prototype.initialize()
	intrinsics.create_web_constructor(metadata, mut mutable_prototype)
	return prototype
}

pub fn (mut intrinsics Intrinsics) create_web_constructor(metadata InterfaceObjectMetadata, mut prototype InterfacePrototypeObject) &InterfaceConstructor {
	key := metadata.utf16_namespaced_name
	mut constructor := InterfaceConstructor.create(intrinsics.realm, metadata)
	intrinsics.constructors[key] = constructor
	prototype.constructor_ = constructor
	constructor.initialize(intrinsics)
	return constructor
}

// https://webidl.spec.whatwg.org/#internally-create-a-new-object-implementing-the-interface
pub fn set_prototype_from_new_target(target_realm &html.ScriptingRealm, prototype ?&PlatformObject, interface_name string, mut object PlatformObject) {
	mut target_intrinsics := host_defined_intrinsics(target_realm)
	installed_prototype := prototype or { target_intrinsics.ensure_web_prototype(interface_name).object }
	object.internal_set_prototype_of(installed_prototype)
	mut wrapper_intrinsics := host_defined_intrinsics(object.realm())
	interface_prototype := wrapper_intrinsics.ensure_web_prototype(interface_name).object
	if voidptr(installed_prototype) != voidptr(interface_prototype) {
		if mut wrappable := object.wrappable_impl() {
			preserve_wrapper(mut wrappable, object)
		}
	}
}

pub fn (mut intrinsics Intrinsics) ensure_web_unforgeable_function(interface_name string, attribute_name string, behavior NativeFunctionBehavior, type_ UnforgeableFunctionType) &NativeFunction {
	key := UnforgeableKey{interface_name, attribute_name, type_}.cache_key()
	if index := intrinsics.unforgeable_function_indices[key] {
		return intrinsics.unforgeable_functions[index]
	}
	function := &NativeFunction{
		name: attribute_name
		length: if type_ == .setter { 1 } else { 0 }
		prefix: if type_ == .setter { 'set' } else { 'get' }
		behavior: behavior
	}
	intrinsics.unforgeable_function_indices[key] = intrinsics.unforgeable_functions.len
	intrinsics.unforgeable_functions << function
	return function
}

pub fn (intrinsics &Intrinsics) namespace_count() int {
	return intrinsics.namespaces.len
}

pub fn (intrinsics &Intrinsics) prototype_count() int {
	return intrinsics.prototypes.len
}

pub fn (intrinsics &Intrinsics) constructor_count() int {
	return intrinsics.constructors.len
}

pub fn (intrinsics &Intrinsics) unforgeable_function_count() int {
	return intrinsics.unforgeable_functions.len
}
