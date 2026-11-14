module libjs

import math

fn test_default_global_property_order_follows_upstream_function_then_value_installation() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	// GlobalObject.cpp::set_default_global_bindings, omitting the eval function
	// and other constructor/prototype entries, which are pending.
	assert vm.get_global_object().own_property_keys().map(it.str()) == ['isFinite', 'isNaN',
		'parseFloat', 'parseInt', 'decodeURI', 'decodeURIComponent', 'encodeURI', 'encodeURIComponent',
		'globalThis', 'Infinity', 'NaN', 'undefined', 'Array', 'ArrayBuffer', 'Boolean', 'DataView',
		'Object', 'RegExp', 'SharedArrayBuffer', 'String', 'Symbol', 'Math', 'escape', 'unescape']
}

fn test_default_global_value_bindings_have_standard_descriptors() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	global := vm.global_object()
	assert math.is_nan(global.get(mut vm, PropertyName.from_str('NaN'))!.number)
	assert math.is_inf(global.get(mut vm, PropertyName.from_str('Infinity'))!.number, 1)
	assert global.get(mut vm, PropertyName.from_str('undefined'))!.is_undefined()
	assert global.get(mut vm, PropertyName.from_str('globalThis'))!.as_object() == global
	for name in ['NaN', 'Infinity', 'undefined'] {
		descriptor := global.internal_get_own_property(PropertyName.from_str(name))?
		assert descriptor.writable? == false
		assert descriptor.enumerable? == false
		assert descriptor.configurable? == false
	}
	descriptor := global.internal_get_own_property(PropertyName.from_str('globalThis'))?
	assert descriptor.writable? && descriptor.configurable?
	assert !descriptor.enumerable?
}

fn test_global_this_binding_uses_the_host_supplied_this_value() {
	mut vm := VM.create()
	initialize_host_defined_realm(mut vm, RealmGlobalHooks{
		create_global_this_value: fn (realm &Realm) &Object {
			mut proxy := Object.create(realm, none)
			proxy.class_name = 'WindowProxy'
			return proxy
		}
	})!
	global := vm.global_object()
	proxy := global.get(mut vm, PropertyName.from_str('globalThis'))!.as_object()
	assert proxy == vm.realm().global_environment_record().global_this_value
	assert proxy.class_name == 'WindowProxy'
	assert proxy != global
}

fn test_intrinsic_constructors_exist_before_the_host_creates_its_global_object() {
	mut vm := VM.create()
	initialize_host_defined_realm(mut vm, RealmGlobalHooks{
		create_global_object: fn (realm &Realm) &Object {
			assert realm.object_constructor != none
			assert realm.array_constructor != none
			assert realm.string_constructor != none
			assert realm.regexp_constructor != none
			return Object.create(realm, realm.object_prototype)
		}
	})!
}
