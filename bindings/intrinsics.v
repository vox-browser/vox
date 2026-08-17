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

fn undefined_native_function(_ []dom.JSValue) !dom.JSValue {
	return dom.js_undefined()
}

@[heap]
pub struct Intrinsics {
pub:
	realm &html.ScriptingRealm
mut:
	objects                      []&IntrinsicObject
	namespace_indices            map[string]int
	prototype_indices            map[string]int
	constructor_indices          map[string]int
	constructors                 []&NativeFunction
	unforgeable_function_indices map[string]int
	unforgeable_functions        []&NativeFunction
}

pub fn Intrinsics.create(realm &html.ScriptingRealm) &Intrinsics {
	return &Intrinsics{
		realm: realm
	}
}

fn (mut intrinsics Intrinsics) ensure_object(name string, kind IntrinsicObjectKind) &IntrinsicObject {
	indices := match kind {
		.namespace_ { intrinsics.namespace_indices }
		.prototype { intrinsics.prototype_indices }
		.constructor { intrinsics.constructor_indices }
	}
	if index := indices[name] {
		return intrinsics.objects[index]
	}
	object := &IntrinsicObject{
		name: name
		kind: kind
	}
	index := intrinsics.objects.len
	intrinsics.objects << object
	match kind {
		.namespace_ { intrinsics.namespace_indices[name] = index }
		.prototype { intrinsics.prototype_indices[name] = index }
		.constructor { intrinsics.constructor_indices[name] = index }
	}
	return object
}

pub fn (mut intrinsics Intrinsics) ensure_web_namespace(namespace_name string) &IntrinsicObject {
	return intrinsics.ensure_object(namespace_name, .namespace_)
}

pub fn (mut intrinsics Intrinsics) ensure_web_prototype(class_name string) &IntrinsicObject {
	prototype := intrinsics.ensure_object(class_name, .prototype)
	if class_name !in intrinsics.constructor_indices {
		constructor_object := intrinsics.ensure_object(class_name, .constructor)
		_ = constructor_object
		intrinsics.constructors << &NativeFunction{
			name:     class_name
			length:   0
			behavior: undefined_native_function
		}
	}
	return prototype
}

pub fn (mut intrinsics Intrinsics) ensure_web_constructor(class_name string) &NativeFunction {
	_ = intrinsics.ensure_web_prototype(class_name)
	index := intrinsics.constructor_indices[class_name] or { 0 }
	// Object and native-function vectors are deliberately separate. Constructor
	// objects are appended in constructor creation order, so count preceding
	// constructor entries to find the corresponding function.
	mut function_index := 0
	for object_index in 0 .. index {
		if intrinsics.objects[object_index].kind == .constructor {
			function_index++
		}
	}
	return intrinsics.constructors[function_index]
}

pub fn (mut intrinsics Intrinsics) ensure_web_unforgeable_function(interface_name string, attribute_name string, behavior NativeFunctionBehavior, type_ UnforgeableFunctionType) &NativeFunction {
	key := UnforgeableKey{interface_name, attribute_name, type_}.cache_key()
	if index := intrinsics.unforgeable_function_indices[key] {
		return intrinsics.unforgeable_functions[index]
	}
	function := &NativeFunction{
		name:     attribute_name
		length:   if type_ == .setter { 1 } else { 0 }
		prefix:   if type_ == .setter { 'set' } else { 'get' }
		behavior: behavior
	}
	intrinsics.unforgeable_function_indices[key] = intrinsics.unforgeable_functions.len
	intrinsics.unforgeable_functions << function
	return function
}

pub fn (intrinsics &Intrinsics) namespace_count() int {
	return intrinsics.namespace_indices.len
}

pub fn (intrinsics &Intrinsics) prototype_count() int {
	return intrinsics.prototype_indices.len
}

pub fn (intrinsics &Intrinsics) constructor_count() int {
	return intrinsics.constructor_indices.len
}

pub fn (intrinsics &Intrinsics) unforgeable_function_count() int {
	return intrinsics.unforgeable_functions.len
}
