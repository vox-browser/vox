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

fn test_legacy_platform_object_internal_methods_and_key_ordering() {
	realm := &html.ScriptingRealm{}
	mut prototype := PlatformObject.create(realm)
	assert prototype.define_ordinary_property(property_key('blocked'), data_property_descriptor(dom.js_number(1),
		true, true, true))

	state := &PlatformHookState{
		indexed: [dom.js_string('zero'), dom.js_string('one')]
		named:   {
			'visible': dom.js_string('named value')
			'blocked': dom.js_string('hidden by prototype')
		}
	}
	mut object := PlatformObject.create_with_prototype(prototype)
	object.expose_interface('TestCollection', ['Collection'])
	object.configure_legacy_platform_object(LegacyPlatformObjectFlags{
		supports_indexed_properties: true
		supports_named_properties:   true
		has_indexed_property_setter: true
		has_named_property_setter:   true
		has_named_property_deleter:  true
	}, LegacyPlatformObjectHooks{
		item_value:                             fn [state] (index u32) ?dom.JSValue {
			if index >= state.indexed.len {
				return none
			}
			return state.indexed[index]
		}
		named_item_value:                       fn [state] (name string) dom.JSValue {
			return state.named[name] or { dom.js_undefined() }
		}
		supported_property_names:               fn [state] () []string {
			return state.named.keys()
		}
		set_value_of_new_indexed_property:      fn [state] (index u32, value dom.JSValue) ! {
			mut mutable_state := unsafe { &PlatformHookState(state) }
			for mutable_state.indexed.len <= index {
				mutable_state.indexed << dom.js_undefined()
			}
			mutable_state.indexed[index] = value
			mutable_state.setter_log << 'new-index:${index}'
		}
		set_value_of_existing_indexed_property: fn [state] (index u32, value dom.JSValue) ! {
			mut mutable_state := unsafe { &PlatformHookState(state) }
			mutable_state.indexed[index] = value
			mutable_state.setter_log << 'index:${index}'
		}
		set_value_of_new_named_property:        fn [state] (name string, value dom.JSValue) ! {
			mut mutable_state := unsafe { &PlatformHookState(state) }
			mutable_state.named[name] = value
			mutable_state.setter_log << 'new-name:${name}'
		}
		set_value_of_existing_named_property:   fn [state] (name string, value dom.JSValue) ! {
			mut mutable_state := unsafe { &PlatformHookState(state) }
			mutable_state.named[name] = value
			mutable_state.setter_log << 'name:${name}'
		}
		delete_value:                           fn [state] (name string) !DidDeletionFail {
			mut mutable_state := unsafe { &PlatformHookState(state) }
			mutable_state.named.delete(name)
			mutable_state.deleter_log << name
			return .no
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

	assert object.define_ordinary_property(property_key('ordinary'), data_property_descriptor(dom.js_bool(true),
		true, true, true))
	assert object.define_ordinary_property(symbol_property_key('token'), data_property_descriptor(dom.js_number(7),
		true, false, true))
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
	realm := &html.ScriptingRealm{}
	mut object := PlatformObject.create(realm)
	key := property_key('fixed')
	assert object.internal_define_own_property(key, data_property_descriptor(dom.js_number(1),
		false, true, false)) or { panic(err) }
	assert !object.internal_set(key, dom.js_number(2), true) or { panic(err) }
	assert !object.internal_delete(key) or { panic(err) }
	assert object.internal_prevent_extensions()
	assert !object.is_extensible()
	assert !object.define_ordinary_property(property_key('late'), data_property_descriptor(dom.js_number(1),
		true, true, true))
}
