@[has_globals]
module bindings

import dom
import html

@[heap]
struct PlatformHookState {
mut:
	indexed     []dom.JSValue
	named       map[string]dom.JSValue
	setter_log  []string
	deleter_log []string
}

@[heap]
struct SupportedNamesEnumerationState {
mut:
	names_calls int
	checks int
}

fn test_own_keys_checks_supported_names_once_and_preserves_visibility_and_order() {
	realm := platform_object_test_realm()
	mut prototype := PlatformObject.create(realm)
	assert prototype.define_ordinary_property(property_key('blocked'), data_property_descriptor(dom.js_number(1), true, true, true))
	mut state := &SupportedNamesEnumerationState{}
	mut object := PlatformObject.create_with_prototype(prototype)
	object.configure_legacy_platform_object(LegacyPlatformObjectFlags{
		supports_indexed_properties: true
		supports_named_properties: true
	}, LegacyPlatformObjectHooks{
		item_value: fn (_ &WrapperWorld, _ &html.ScriptingRealm, index u32) ?dom.JSValue {
			if index < 2 { return dom.js_number(index) }
			return none
		}
		supported_property_names: fn [mut state] () []string {
			state.names_calls++
			return ['0', 'visible', 'visible', 'blocked', 'ordinary']
		}
		is_supported_property_name: fn [mut state] (name string) bool {
			state.checks++
			return name in ['0', 'visible', 'blocked', 'ordinary']
		}
	})
	assert object.define_ordinary_property(property_key('ordinary'), data_property_descriptor(dom.js_number(2), true, true, true))
	assert object.define_ordinary_property(symbol_property_key('visible'), data_property_descriptor(dom.js_number(3), true, true, true))
	assert object.internal_own_property_keys() == [property_key('0'), property_key('1'),
		property_key('visible'), property_key('ordinary'), symbol_property_key('visible')]
	assert state.names_calls == 1
	assert state.checks == 0
	assert object.is_named_property_exposed_on_object(property_key('visible'))
	assert !object.is_named_property_exposed_on_object(property_key('missing'))
	assert !object.is_named_property_exposed_on_object(property_key('blocked'))
	assert !object.is_named_property_exposed_on_object(property_key('ordinary'))
	assert !object.is_named_property_exposed_on_object(symbol_property_key('visible'))
	assert state.checks == 4
}

fn platform_object_test_realm() &html.ScriptingRealm {
	reset_main_thread_vm_for_testing()
	return create_a_principal_javascript_realm()
}

fn test_legacy_platform_object_internal_methods_and_key_ordering() {
	realm := platform_object_test_realm()
	mut prototype := PlatformObject.create(realm)
	assert prototype.define_ordinary_property(property_key('blocked'), data_property_descriptor(dom.js_number(1), true, true, true))

	state := &PlatformHookState{
		indexed: [dom.js_string('zero'), dom.js_string('one')]
		named: {
			'visible': dom.js_string('named value')
			'blocked': dom.js_string('hidden by prototype')
		}
	}
	mut object := PlatformObject.create_with_prototype(prototype)
	object.expose_interface('TestCollection', ['Collection'])
	object.configure_legacy_platform_object(LegacyPlatformObjectFlags{
		supports_indexed_properties: true
		supports_named_properties: true
		has_indexed_property_setter: true
		has_named_property_setter: true
		has_named_property_deleter: true
	}, LegacyPlatformObjectHooks{
		item_value: fn [state] (_ &WrapperWorld, _ &html.ScriptingRealm, index u32) ?dom.JSValue {
			if index >= state.indexed.len {
				return none
			}
			return state.indexed[index]
		}
		named_item_value: fn [state] (_ &WrapperWorld, _ &html.ScriptingRealm, name string) dom.JSValue {
			return state.named[name] or { dom.js_undefined() }
		}
		supported_property_names: fn [state] () []string {
			return state.named.keys()
		}
		set_value_of_new_indexed_property: fn [state] (_ &html.ScriptingRealm, index u32, value dom.JSValue) ! {
			mut mutable_state := unsafe { &PlatformHookState(state) }
			for mutable_state.indexed.len <= index {
				mutable_state.indexed << dom.js_undefined()
			}
			mutable_state.indexed[index] = value
			mutable_state.setter_log << 'new-index:${index}'
		}
		set_value_of_existing_indexed_property: fn [state] (_ &html.ScriptingRealm, index u32, value dom.JSValue) ! {
			mut mutable_state := unsafe { &PlatformHookState(state) }
			mutable_state.indexed[index] = value
			mutable_state.setter_log << 'index:${index}'
		}
		set_value_of_new_named_property: fn [state] (_ &html.ScriptingRealm, name string, value dom.JSValue) ! {
			mut mutable_state := unsafe { &PlatformHookState(state) }
			mutable_state.named[name] = value
			mutable_state.setter_log << 'new-name:${name}'
		}
		set_value_of_existing_named_property: fn [state] (_ &html.ScriptingRealm, name string, value dom.JSValue) ! {
			mut mutable_state := unsafe { &PlatformHookState(state) }
			mutable_state.named[name] = value
			mutable_state.setter_log << 'name:${name}'
		}
		delete_value: fn [state] (name string) !NamedPropertyDeletionResult {
			mut mutable_state := unsafe { &PlatformHookState(state) }
			mutable_state.named.delete(name)
			mutable_state.deleter_log << name
			return .did_not_fail
		}
	})
	assert object.implements_interface('TestCollection')
	assert object.implements_interface('Collection')
	assert object.interface_name() or { '' } == 'TestCollection'

	indexed := object.internal_get_own_property(property_key('0')) or { panic('missing index') }
	assert indexed.value or { dom.js_undefined() }.string_data == 'zero'
	named := object.internal_get_own_property(property_key('visible')) or { panic('missing name') }
	assert named.value or { dom.js_undefined() }.string_data == 'named value'
	assert object.internal_get_own_property(property_key('blocked')) == none

	assert object.define_ordinary_property(property_key('ordinary'), data_property_descriptor(dom.js_bool(true), true, true, true))
	assert object.define_ordinary_property(symbol_property_key('token'), data_property_descriptor(dom.js_number(7), true, false, true))
	keys := object.internal_own_property_keys()
	assert keys[0].name == '0'
	assert keys[1].name == '1'
	assert property_key('visible') in keys
	assert property_key('blocked') !in keys
	assert keys[keys.len - 1] == symbol_property_key('token')

	assert object.internal_set(property_key('1'), dom.js_string('updated'), true) or { panic(err) }
	assert object.internal_set(property_key('visible'), dom.js_string('changed'), true) or {
		panic(err)
	}
	assert state.setter_log == ['index:1', 'name:visible']
	assert state.indexed[1].string_data == 'updated'
	changed_named := state.named['visible'] or { panic('missing changed named value') }
	assert changed_named.string_data == 'changed'
	assert !object.internal_delete(property_key('0')) or { panic(err) }
	assert object.internal_delete(property_key('visible')) or { panic(err) }
	assert state.deleter_log == ['visible']
	assert !object.internal_prevent_extensions()
}

fn test_platform_object_ordinary_descriptor_invariants() {
	realm := platform_object_test_realm()
	mut object := PlatformObject.create(realm)
	key := property_key('fixed')
	assert object.internal_define_own_property(key, data_property_descriptor(dom.js_number(1), false, true, false)) or { panic(err) }
	assert !object.internal_set(key, dom.js_number(2), true) or { panic(err) }
	assert !object.internal_delete(key) or { panic(err) }
	assert object.internal_prevent_extensions()
	assert !object.is_extensible()
	assert !object.define_ordinary_property(property_key('late'), data_property_descriptor(dom.js_number(1), true, true, true))
}

fn test_platform_object_exact_realm_setter_deleter_and_fast_path_entry_points() {
	realm := platform_object_test_realm()
	state := &PlatformHookState{}
	mut object := PlatformObject.create(realm)
	assert object.realm() == realm
	assert !object.eligible_for_own_property_enumeration_fast_path()
	object.configure_legacy_platform_object(LegacyPlatformObjectFlags{}, LegacyPlatformObjectHooks{
		set_value_of_new_named_property: fn [state] (_ &html.ScriptingRealm, name string, _ dom.JSValue) ! {
			unsafe { state.setter_log << 'new-name:${name}' }
		}
		set_value_of_existing_named_property: fn [state] (_ &html.ScriptingRealm, name string, _ dom.JSValue) ! {
			unsafe { state.setter_log << 'name:${name}' }
		}
		set_value_of_named_property: fn [state] (_ &html.ScriptingRealm, name string, _ dom.JSValue) ! {
			unsafe { state.setter_log << 'identified-name:${name}' }
		}
		set_value_of_new_indexed_property: fn [state] (_ &html.ScriptingRealm, index u32, _ dom.JSValue) ! {
			unsafe { state.setter_log << 'new-index:${index}' }
		}
		set_value_of_existing_indexed_property: fn [state] (_ &html.ScriptingRealm, index u32, _ dom.JSValue) ! {
			unsafe { state.setter_log << 'index:${index}' }
		}
		set_value_of_indexed_property: fn [state] (_ &html.ScriptingRealm, index u32, _ dom.JSValue) ! {
			unsafe { state.setter_log << 'identified-index:${index}' }
		}
		delete_value: fn [state] (name string) !NamedPropertyDeletionResult {
			unsafe { state.deleter_log << name }
			return .did_not_fail
		}
	})
	value := dom.js_string('value')
	object.set_value_of_new_named_property(realm, 'a', value)!
	object.set_value_of_existing_named_property(realm, 'b', value)!
	object.set_value_of_named_property(realm, 'c', value)!
	object.set_value_of_new_indexed_property(realm, 1, value)!
	object.set_value_of_existing_indexed_property(realm, 2, value)!
	object.set_value_of_indexed_property(realm, 3, value)!
	assert object.delete_value('d')! == .did_not_fail
	assert state.setter_log == ['new-name:a', 'name:b', 'identified-name:c', 'new-index:1', 'index:2',
		'identified-index:3']
	assert state.deleter_log == ['d']
}

fn test_platform_object_delegates_wrappable_identity_and_cacheability() {
	realm := platform_object_test_realm()
	mut world := unsafe { &WrapperWorld(host_defined_wrapper_world(realm)) }
	mut implementation := Wrappable.create('Document', ['Node', 'EventTarget'])
	implementation.supported_property_names_ = ['named-entry']
	implementation.origin_ = dom.Origin{
		value: 'https://example.test'
	}
	mut wrapper := wrap(mut world, realm, mut implementation)
	assert wrapper.wrapped_implementation_offset() == 0
	assert wrapper.interface_name() or { '' } == 'Document'
	assert wrapper.implements_interface('Node')
	assert wrapper.extract_an_origin()?.serialize() == 'https://example.test'
	assert wrapper.is_cacheable_for_property_absence()
	assert wrapper.is_cacheable_for_inherited_property()

	wrapper.configure_legacy_platform_object(LegacyPlatformObjectFlags{
		supports_named_properties: true
		has_legacy_override_built_ins_interface_attribute: true
	}, LegacyPlatformObjectHooks{})
	assert wrapper.is_named_property_exposed_on_object(property_key('named-entry'))
	assert !wrapper.is_cacheable_for_property_absence()
	assert wrapper.is_cacheable_for_inherited_property()

	mut collection_implementation := Wrappable.create('HTMLCollection', [])
	mut collection_wrapper := wrap(mut world, realm, mut collection_implementation)
	collection_wrapper.configure_legacy_platform_object(LegacyPlatformObjectFlags{
		supports_named_properties: true
		has_legacy_override_built_ins_interface_attribute: true
	}, LegacyPlatformObjectHooks{})
	assert !collection_wrapper.is_cacheable_for_inherited_property()
}

fn test_platform_object_mutations_preserve_wrappers_and_finalize_clears_cache() {
	realm := platform_object_test_realm()
	mut world := unsafe { &WrapperWorld(host_defined_wrapper_world(realm)) }

	mut expando_implementation := Wrappable.create('ExpandoInterface', [])
	mut expando_wrapper := wrap(mut world, realm, mut expando_implementation)
	assert expando_wrapper.requires_slow_add_own_property()
	assert expando_wrapper.internal_define_own_property(property_key('expando'), data_property_descriptor(dom.js_number(1), true, true, true)) or { panic(err) }
	assert wrapper_is_preserved(expando_wrapper)
	assert !expando_wrapper.requires_slow_add_own_property()

	mut prototype_implementation := Wrappable.create('PrototypeInterface', [])
	mut prototype_wrapper := wrap(mut world, realm, mut prototype_implementation)
	custom_prototype := PlatformObject.create(realm)
	assert prototype_wrapper.internal_set_prototype_of(custom_prototype)
	assert prototype_wrapper.prototype()? == custom_prototype
	assert wrapper_is_preserved(prototype_wrapper)

	mut non_extensible_implementation := Wrappable.create('NonExtensibleInterface', [])
	mut non_extensible_wrapper := wrap(mut world, realm, mut non_extensible_implementation)
	assert non_extensible_wrapper.internal_prevent_extensions()
	assert wrapper_is_preserved(non_extensible_wrapper)

	mut released_implementation := Wrappable.create('ReleasedInterface', [])
	mut released_wrapper := wrap(mut world, realm, mut released_implementation)
	assert world.wrapper_for(released_implementation, realm)? == released_wrapper
	released_wrapper.finalize()
	assert world.wrapper_for(released_implementation, realm) == none
}
