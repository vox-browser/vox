// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Bindings/InterfaceObject.{h,cpp}.
module bindings

import dom
import html

pub type EnsureParentPrototypeFunction = fn (&html.ScriptingRealm) &InterfacePrototypeObject

pub type EnsureParentConstructorFunction = fn (&html.ScriptingRealm) &InterfaceConstructor

pub type InitializeInterfaceConstructorFunction = fn (&html.ScriptingRealm, mut InterfaceConstructor)

pub type InitializeInterfacePrototypeFunction = fn (&html.ScriptingRealm, mut InterfacePrototypeObject)

pub type DefineUnforgeableAttributesFunction = fn (&html.ScriptingRealm, voidptr)

pub type InterfaceConstructFunction = fn (&InterfaceConstructor, &NativeFunction) !&PlatformObject

pub struct InterfaceObjectMetadata {
pub:
	name                          string
	namespaced_name               string
	utf16_name                    string
	utf16_namespaced_name         string
	ensure_parent_prototype       ?EnsureParentPrototypeFunction
	ensure_parent_constructor     ?EnsureParentConstructorFunction
	initialize_constructor        ?InitializeInterfaceConstructorFunction
	initialize_prototype          ?InitializeInterfacePrototypeFunction
	define_unforgeable_attributes ?DefineUnforgeableAttributesFunction
	construct                     ?InterfaceConstructFunction
	has_immutable_prototype       bool
}

pub fn InterfaceObjectMetadata.create(name string) InterfaceObjectMetadata {
	return InterfaceObjectMetadata{
		name: name
		namespaced_name: name
		utf16_name: name
		utf16_namespaced_name: name
	}
}

@[heap]
pub struct InterfacePrototypeObject {
pub:
	realm    &html.ScriptingRealm
	metadata InterfaceObjectMetadata
	object   &PlatformObject
pub mut:
	prototype_    ?&InterfacePrototypeObject
	to_string_tag string
	constructor_  ?&InterfaceConstructor
}

pub fn InterfacePrototypeObject.create(realm &html.ScriptingRealm, metadata InterfaceObjectMetadata) &InterfacePrototypeObject {
	return &InterfacePrototypeObject{
		realm: realm
		metadata: metadata
		object: PlatformObject.create(realm)
	}
}

pub fn (mut object InterfacePrototypeObject) initialize() {
	if initialize := object.metadata.initialize_prototype {
		initialize(object.realm, mut object)
		return
	}
	if ensure_parent := object.metadata.ensure_parent_prototype {
		parent := ensure_parent(object.realm)
		object.prototype_ = parent
		mut platform_object := unsafe { &PlatformObject(object.object) }
		platform_object.set_prototype(parent.object)
	}
	object.to_string_tag = object.metadata.utf16_namespaced_name
}

pub fn (object &InterfacePrototypeObject) class_name() string {
	return object.metadata.name
}

pub fn (object &InterfacePrototypeObject) define_unforgeable_attributes(realm &html.ScriptingRealm, target voidptr) {
	if define := object.metadata.define_unforgeable_attributes {
		define(realm, target)
	}
}

fn same_interface_prototype(left ?&InterfacePrototypeObject, right ?&InterfacePrototypeObject) bool {
	left_prototype := left or { return right == none }
	right_prototype := right or { return false }
	return voidptr(left_prototype) == voidptr(right_prototype)
}

pub fn (mut object InterfacePrototypeObject) internal_set_prototype_of(prototype ?&InterfacePrototypeObject) bool {
	if object.metadata.has_immutable_prototype {
		return same_interface_prototype(object.prototype_, prototype)
	}
	object.prototype_ = prototype
	mut platform_object := unsafe { &PlatformObject(object.object) }
	if parent := prototype {
		platform_object.set_prototype(parent.object)
	} else {
		platform_object.set_prototype(none)
	}
	return true
}

@[heap]
pub struct InterfaceConstructor {
pub:
	realm    &html.ScriptingRealm
	metadata InterfaceObjectMetadata
pub mut:
	parent_           ?&InterfaceConstructor
	prototype_object_ ?&InterfacePrototypeObject
	name              string
	length            int
}

pub fn InterfaceConstructor.create(realm &html.ScriptingRealm, metadata InterfaceObjectMetadata) &InterfaceConstructor {
	return &InterfaceConstructor{
		realm: realm
		metadata: metadata
		name: metadata.utf16_name
	}
}

pub fn (constructor &InterfaceConstructor) call() !dom.JSValue {
	return error("TypeError: Constructor ${constructor.metadata.namespaced_name} requires 'new'")
}

pub fn (constructor &InterfaceConstructor) construct(new_target &NativeFunction) !&PlatformObject {
	if construct := constructor.metadata.construct {
		return construct(constructor, new_target)
	}
	return error('TypeError: ${constructor.metadata.namespaced_name} is not a constructor')
}

pub fn (mut constructor InterfaceConstructor) initialize(intrinsics &Intrinsics) {
	if initialize := constructor.metadata.initialize_constructor {
		initialize(constructor.realm, mut constructor)
		return
	}
	if ensure_parent := constructor.metadata.ensure_parent_constructor {
		constructor.parent_ = ensure_parent(constructor.realm)
	}
	constructor.length = 0
	constructor.name = constructor.metadata.utf16_name
	constructor.prototype_object_ = intrinsics.existing_web_prototype(constructor.metadata.utf16_namespaced_name)
}

pub fn (constructor &InterfaceConstructor) class_name() string {
	return constructor.metadata.name
}

pub fn (_ &InterfaceConstructor) has_constructor() bool {
	return true
}
