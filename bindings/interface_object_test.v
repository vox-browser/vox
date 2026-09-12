@[has_globals]
module bindings

import dom
import html

@[heap]
struct InterfaceObjectTestTarget {
mut:
	definition_count int
}

fn interface_object_test_behavior(_ []dom.JSValue) !dom.JSValue {
	return dom.js_undefined()
}

fn interface_object_test_ensure_parent_prototype(realm &html.ScriptingRealm) &InterfacePrototypeObject {
	mut intrinsics := host_defined_intrinsics(realm)
	return intrinsics.ensure_web_prototype('ParentInterface')
}

fn interface_object_test_ensure_parent_constructor(realm &html.ScriptingRealm) &InterfaceConstructor {
	mut intrinsics := host_defined_intrinsics(realm)
	return intrinsics.ensure_web_constructor('ParentInterface')
}

fn interface_object_test_initialize_prototype(_ &html.ScriptingRealm, mut prototype InterfacePrototypeObject) {
	prototype.to_string_tag = 'CustomPrototypeTag'
}

fn interface_object_test_initialize_constructor(_ &html.ScriptingRealm, mut constructor InterfaceConstructor) {
	constructor.name = 'CustomConstructorName'
	constructor.length = 3
}

fn interface_object_test_define_unforgeables(_ &html.ScriptingRealm, target voidptr) {
	mut state := unsafe { &InterfaceObjectTestTarget(target) }
	state.definition_count++
}

fn interface_object_test_construct(constructor &InterfaceConstructor, _ &NativeFunction) !&PlatformObject {
	mut object := PlatformObject.create(constructor.realm)
	object.expose_interface(constructor.metadata.name, [])
	return object
}

fn interface_object_test_realm() &html.ScriptingRealm {
	reset_main_thread_vm_for_testing()
	return create_a_principal_javascript_realm()
}

fn test_interface_objects_are_initialized_and_cached_from_metadata() {
	realm := interface_object_test_realm()
	mut intrinsics := host_defined_intrinsics(realm)
	metadata := InterfaceObjectMetadata{
		name: 'ChildInterface'
		namespaced_name: 'Namespace.ChildInterface'
		utf16_name: 'ChildInterface'
		utf16_namespaced_name: 'Namespace.ChildInterface'
		ensure_parent_prototype: interface_object_test_ensure_parent_prototype
		ensure_parent_constructor: interface_object_test_ensure_parent_constructor
	}
	prototype := intrinsics.ensure_web_prototype_with_metadata(metadata)
	constructor := intrinsics.ensure_web_constructor('Namespace.ChildInterface')
	parent_prototype := intrinsics.ensure_web_prototype('ParentInterface')
	parent_constructor := intrinsics.ensure_web_constructor('ParentInterface')

	assert intrinsics.ensure_web_prototype_with_metadata(metadata) == prototype
	assert intrinsics.ensure_web_constructor('Namespace.ChildInterface') == constructor
	assert prototype.prototype_? == parent_prototype
	assert prototype.object.prototype()? == parent_prototype.object
	assert prototype.to_string_tag == 'Namespace.ChildInterface'
	assert prototype.constructor_? == constructor
	assert prototype.class_name() == 'ChildInterface'
	assert constructor.parent_? == parent_constructor
	assert constructor.prototype_object_? == prototype
	assert constructor.name == 'ChildInterface'
	assert constructor.length == 0
	assert constructor.class_name() == 'ChildInterface'
	assert constructor.has_constructor()
}

fn test_interface_object_callbacks_and_constructor_failures() {
	realm := interface_object_test_realm()
	mut intrinsics := host_defined_intrinsics(realm)
	metadata := InterfaceObjectMetadata{
		name: 'CustomInterface'
		namespaced_name: 'Namespace.CustomInterface'
		utf16_name: 'CustomInterface'
		utf16_namespaced_name: 'Namespace.CustomInterface'
		initialize_prototype: interface_object_test_initialize_prototype
		initialize_constructor: interface_object_test_initialize_constructor
		define_unforgeable_attributes: interface_object_test_define_unforgeables
		construct: interface_object_test_construct
	}
	prototype := intrinsics.ensure_web_prototype_with_metadata(metadata)
	constructor := intrinsics.ensure_web_constructor('Namespace.CustomInterface')
	assert prototype.to_string_tag == 'CustomPrototypeTag'
	assert constructor.name == 'CustomConstructorName'
	assert constructor.length == 3

	mut target := &InterfaceObjectTestTarget{}
	prototype.define_unforgeable_attributes(realm, voidptr(target))
	assert target.definition_count == 1

	if _ := constructor.call() {
		assert false
	} else {
		assert err.msg().contains("Constructor Namespace.CustomInterface requires 'new'")
	}
	new_target := &NativeFunction{
		name: 'Derived'
		length: 0
		behavior: interface_object_test_behavior
	}
	instance := constructor.construct(new_target) or { panic(err) }
	assert instance.interface_name() or { '' } == 'CustomInterface'

	non_constructor := intrinsics.ensure_web_constructor('NonConstructor')
	if _ := non_constructor.construct(new_target) {
		assert false
	} else {
		assert err.msg().contains('NonConstructor is not a constructor')
	}
}

fn test_interface_prototype_can_be_immutable() {
	realm := interface_object_test_realm()
	mut intrinsics := host_defined_intrinsics(realm)
	metadata := InterfaceObjectMetadata{
		name: 'ImmutableInterface'
		namespaced_name: 'ImmutableInterface'
		utf16_name: 'ImmutableInterface'
		utf16_namespaced_name: 'ImmutableInterface'
		ensure_parent_prototype: interface_object_test_ensure_parent_prototype
		has_immutable_prototype: true
	}
	prototype := intrinsics.ensure_web_prototype_with_metadata(metadata)
	parent := prototype.prototype_ or { panic('missing parent prototype') }
	mut mutable_prototype := unsafe { &InterfacePrototypeObject(prototype) }
	assert mutable_prototype.internal_set_prototype_of(parent)
	other_parent := intrinsics.ensure_web_prototype('OtherParent')
	assert !mutable_prototype.internal_set_prototype_of(other_parent)
	assert prototype.prototype_? == parent
}

fn test_set_prototype_from_new_target_preserves_custom_prototype_wrappers() {
	realm := interface_object_test_realm()
	mut intrinsics := host_defined_intrinsics(realm)
	default_prototype := intrinsics.ensure_web_prototype('PreservedInterface').object
	mut world := unsafe { &WrapperWorld(host_defined_wrapper_world(realm)) }
	mut implementation := Wrappable.create('PreservedInterface', [])
	mut wrapper := wrap(mut world, realm, mut implementation)

	set_prototype_from_new_target(realm, none, 'PreservedInterface', mut wrapper)
	assert wrapper.prototype()? == default_prototype
	assert !wrapper_is_preserved(wrapper)

	custom_prototype := PlatformObject.create(realm)
	set_prototype_from_new_target(realm, custom_prototype, 'PreservedInterface', mut wrapper)
	assert wrapper.prototype()? == custom_prototype
	assert wrapper_is_preserved(wrapper)
}
