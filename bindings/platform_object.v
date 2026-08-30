// Copyright (c) 2022-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Bindings/PlatformObject.{h,cpp}. This is the WebIDL legacy
// platform-object internal-method model used until LibJS itself is available
// in V. Property keys, descriptors, prototype visibility, indexed/named
// getters and setters, deletion, extensibility, and key ordering are preserved.
module bindings

import dom
import html

pub enum PropertyKeyKind {
	string
	symbol
}

pub struct PropertyKey {
pub:
	kind PropertyKeyKind
	name string
}

pub fn property_key(name string) PropertyKey {
	return PropertyKey{.string, name}
}

pub fn symbol_property_key(description string) PropertyKey {
	return PropertyKey{.symbol, description}
}

pub fn (key PropertyKey) is_symbol() bool {
	return key.kind == .symbol
}

fn (key PropertyKey) storage_key() string {
	return '${int(key.kind)}\x00${key.name}'
}

// ECMAScript array indices are canonical decimal strings in [0, 2^32 - 2].
pub fn (key PropertyKey) array_index() ?u32 {
	if key.kind != .string || key.name.len == 0 {
		return none
	}
	if key.name.len > 1 && key.name[0] == `0` {
		return none
	}
	mut value := u64(0)
	for character in key.name.bytes() {
		if character < `0` || character > `9` {
			return none
		}
		value = value * 10 + u64(character - `0`)
		if value > 4294967294 {
			return none
		}
	}
	return u32(value)
}

pub struct PropertyDescriptor {
pub:
	value        ?dom.JSValue
	writable     ?bool
	enumerable   ?bool
	configurable ?bool
	accessor     bool
}

pub fn data_property_descriptor(value dom.JSValue, writable bool, enumerable bool, configurable bool) PropertyDescriptor {
	return PropertyDescriptor{
		value:        value
		writable:     writable
		enumerable:   enumerable
		configurable: configurable
	}
}

pub fn accessor_property_descriptor(enumerable bool, configurable bool) PropertyDescriptor {
	return PropertyDescriptor{
		enumerable:   enumerable
		configurable: configurable
		accessor:     true
	}
}

pub fn (descriptor PropertyDescriptor) is_data_descriptor() bool {
	return !descriptor.accessor && (descriptor.value != none || descriptor.writable != none)
}

pub struct LegacyPlatformObjectFlags {
pub:
	supports_indexed_properties                                  bool
	supports_named_properties                                    bool
	has_indexed_property_setter                                  bool
	has_named_property_setter                                    bool
	has_named_property_deleter                                   bool
	has_legacy_unenumerable_named_properties_interface_attribute bool
	has_legacy_override_built_ins_interface_attribute            bool
	has_global_interface_attribute                               bool
	indexed_property_setter_has_identifier                       bool
	named_property_setter_has_identifier                         bool
	named_property_deleter_has_identifier                        bool
}

pub enum DidDeletionFail {
	not_relevant
	no
	yes
}

pub type IndexedPropertyGetter = fn (u32) ?dom.JSValue

pub type NamedPropertyGetter = fn (string) dom.JSValue

pub type SupportedPropertyNamesGetter = fn () []string

pub type SupportedPropertyNameChecker = fn (string) bool

pub type IndexedPropertySetter = fn (u32, dom.JSValue) !

pub type NamedPropertySetter = fn (string, dom.JSValue) !

pub type NamedPropertyDeleter = fn (string) !DidDeletionFail

pub struct LegacyPlatformObjectHooks {
pub:
	item_value                             ?IndexedPropertyGetter
	named_item_value                       ?NamedPropertyGetter
	supported_property_names               ?SupportedPropertyNamesGetter
	is_supported_property_name             ?SupportedPropertyNameChecker
	set_value_of_new_named_property        ?NamedPropertySetter
	set_value_of_existing_named_property   ?NamedPropertySetter
	set_value_of_named_property            ?NamedPropertySetter
	set_value_of_new_indexed_property      ?IndexedPropertySetter
	set_value_of_existing_indexed_property ?IndexedPropertySetter
	set_value_of_indexed_property          ?IndexedPropertySetter
	delete_value                           ?NamedPropertyDeleter
}

@[heap]
pub struct PlatformObject {
mut:
	realm_                   &html.ScriptingRealm
	prototype_               ?&PlatformObject
	interface_name_          string
	implemented_interfaces_  []string
	named_properties_object_ bool
	legacy_flags_            ?LegacyPlatformObjectFlags
	hooks_                   LegacyPlatformObjectHooks
	ordinary_properties_     map[string]PropertyDescriptor
	ordinary_property_order_ []PropertyKey
	extensible_              bool = true
}

pub fn PlatformObject.create(realm &html.ScriptingRealm) &PlatformObject {
	return &PlatformObject{
		realm_: realm
	}
}

pub fn PlatformObject.create_with_prototype(prototype &PlatformObject) &PlatformObject {
	return &PlatformObject{
		realm_:     prototype.realm_
		prototype_: prototype
	}
}

pub fn (object &PlatformObject) realm() &html.ScriptingRealm {
	return object.realm_
}

pub fn (mut object PlatformObject) set_prototype(prototype ?&PlatformObject) {
	object.prototype_ = prototype
}

pub fn (object &PlatformObject) prototype() ?&PlatformObject {
	return object.prototype_
}

pub fn (mut object PlatformObject) set_named_properties_object(value bool) {
	object.named_properties_object_ = value
}

pub fn (mut object PlatformObject) expose_interface(name string, inherited []string) {
	object.interface_name_ = name
	object.implemented_interfaces_ = [name]
	for interface_name in inherited {
		if interface_name !in object.implemented_interfaces_ {
			object.implemented_interfaces_ << interface_name
		}
	}
}

pub fn (object &PlatformObject) implements_interface(name string) bool {
	return name in object.implemented_interfaces_
}

pub fn (object &PlatformObject) interface_name() !string {
	if object.interface_name_.len == 0 {
		return error('Platform object is not exposed over WebIDL')
	}
	return object.interface_name_
}

pub fn (mut object PlatformObject) configure_legacy_platform_object(flags LegacyPlatformObjectFlags, hooks LegacyPlatformObjectHooks) {
	object.legacy_flags_ = flags
	object.hooks_ = hooks
}

pub fn (object &PlatformObject) legacy_platform_object_flags() ?LegacyPlatformObjectFlags {
	return object.legacy_flags_
}

fn js_values_same(left dom.JSValue, right dom.JSValue) bool {
	if left.kind != right.kind {
		return false
	}
	return match left.kind {
		.undefined, .null_ { true }
		.boolean { left.boolean_data == right.boolean_data }
		.number { left.number_data == right.number_data }
		.string { left.string_data == right.string_data }
		.object { left.object_data == right.object_data }
	}
}

fn (object &PlatformObject) ordinary_get_own_property(key PropertyKey) ?PropertyDescriptor {
	return object.ordinary_properties_[key.storage_key()] or { none }
}

fn (mut object PlatformObject) ordinary_define_own_property(key PropertyKey, descriptor PropertyDescriptor) bool {
	storage_key := key.storage_key()
	if current := object.ordinary_properties_[storage_key] {
		if !(current.configurable or { false }) {
			if descriptor.configurable or { false } {
				return false
			}
			if enumerable := descriptor.enumerable {
				if enumerable != (current.enumerable or { false }) {
					return false
				}
			}
			if current.is_data_descriptor() && !(current.writable or { false }) {
				if descriptor.writable or { false } {
					return false
				}
				if new_value := descriptor.value {
					old_value := current.value or { dom.js_undefined() }
					if !js_values_same(old_value, new_value) {
						return false
					}
				}
			}
		}
	} else {
		if !object.extensible_ {
			return false
		}
		object.ordinary_property_order_ << key
	}
	object.ordinary_properties_[storage_key] = descriptor
	return true
}

pub fn (mut object PlatformObject) define_ordinary_property(key PropertyKey, descriptor PropertyDescriptor) bool {
	return object.ordinary_define_own_property(key, descriptor)
}

fn (object &PlatformObject) item_value(index u32) ?dom.JSValue {
	getter := object.hooks_.item_value or { return none }
	return getter(index)
}

fn (object &PlatformObject) named_item_value(name string) dom.JSValue {
	getter := object.hooks_.named_item_value or { return dom.js_undefined() }
	return getter(name)
}

fn (object &PlatformObject) supported_property_names() []string {
	getter := object.hooks_.supported_property_names or { return [] }
	return getter()
}

fn (object &PlatformObject) is_supported_property_name(name string) bool {
	if checker := object.hooks_.is_supported_property_name {
		return checker(name)
	}
	return name in object.supported_property_names()
}

fn (object &PlatformObject) is_supported_property_index(index u32) bool {
	return object.item_value(index) != none
}

// https://webidl.spec.whatwg.org/#dfn-named-property-visibility
pub fn (object &PlatformObject) is_named_property_exposed_on_object(key PropertyKey) bool {
	if key.is_symbol() || !object.is_supported_property_name(key.name) {
		return false
	}
	if object.ordinary_get_own_property(key) != none {
		return false
	}
	flags := object.legacy_flags_ or { return false }
	if flags.has_legacy_override_built_ins_interface_attribute {
		return true
	}
	mut prototype := object.prototype_
	for prototype != none {
		current := prototype or { break }
		if !current.named_properties_object_ && current.ordinary_get_own_property(key) != none {
			return false
		}
		prototype = current.prototype_
	}
	return true
}

fn (object &PlatformObject) legacy_platform_object_get_own_property(key PropertyKey, ignore_named_properties bool) ?PropertyDescriptor {
	flags := object.legacy_flags_ or { return object.ordinary_get_own_property(key) }
	mut ignore_named := ignore_named_properties
	if flags.supports_indexed_properties {
		if index := key.array_index() {
			if value := object.item_value(index) {
				return data_property_descriptor(value, flags.has_indexed_property_setter, true,
					true)
			}
			ignore_named = true
		}
	}
	if flags.supports_named_properties && !ignore_named
		&& object.is_named_property_exposed_on_object(key) {
		return data_property_descriptor(object.named_item_value(key.name),
			flags.has_named_property_setter,
			!flags.has_legacy_unenumerable_named_properties_interface_attribute, true)
	}
	return object.ordinary_get_own_property(key)
}

pub fn (object &PlatformObject) internal_get_own_property(key PropertyKey) ?PropertyDescriptor {
	if flags := object.legacy_flags_ {
		if !flags.has_global_interface_attribute {
			return object.legacy_platform_object_get_own_property(key, false)
		}
	}
	return object.ordinary_get_own_property(key)
}

fn (object &PlatformObject) invoke_indexed_property_setter(key PropertyKey, value dom.JSValue) ! {
	index := key.array_index() or {
		return error('TypeError: indexed property key is not an array index')
	}
	flags := object.legacy_flags_ or {
		return error('TypeError: object is not a legacy platform object')
	}

	creating := !object.is_supported_property_index(index)
	if !flags.indexed_property_setter_has_identifier {
		if creating {
			object.set_value_of_new_indexed_property(index, value)!
			return
		}
		object.set_value_of_existing_indexed_property(index, value)!
		return
	}
	object.set_value_of_indexed_property(index, value)!
}

fn (object &PlatformObject) invoke_named_property_setter(name string, value dom.JSValue) ! {
	flags := object.legacy_flags_ or {
		return error('TypeError: object is not a legacy platform object')
	}

	creating := !object.is_supported_property_name(name)
	if !flags.named_property_setter_has_identifier {
		if creating {
			object.set_value_of_new_named_property(name, value)!
			return
		}
		object.set_value_of_existing_named_property(name, value)!
		return
	}
	object.set_value_of_named_property(name, value)!
}

pub fn (object &PlatformObject) set_value_of_new_named_property(name string, value dom.JSValue) ! {
	setter := object.hooks_.set_value_of_new_named_property or {
		return error('TypeError: named property setter hook is missing')
	}
	setter(name, value)!
}

pub fn (object &PlatformObject) set_value_of_existing_named_property(name string, value dom.JSValue) ! {
	setter := object.hooks_.set_value_of_existing_named_property or {
		return error('TypeError: named property setter hook is missing')
	}
	setter(name, value)!
}

pub fn (object &PlatformObject) set_value_of_named_property(name string, value dom.JSValue) ! {
	setter := object.hooks_.set_value_of_named_property or {
		return error('TypeError: named property setter hook is missing')
	}
	setter(name, value)!
}

pub fn (object &PlatformObject) set_value_of_new_indexed_property(index u32, value dom.JSValue) ! {
	setter := object.hooks_.set_value_of_new_indexed_property or {
		return error('TypeError: indexed property setter hook is missing')
	}
	setter(index, value)!
}

pub fn (object &PlatformObject) set_value_of_existing_indexed_property(index u32, value dom.JSValue) ! {
	setter := object.hooks_.set_value_of_existing_indexed_property or {
		return error('TypeError: indexed property setter hook is missing')
	}
	setter(index, value)!
}

pub fn (object &PlatformObject) set_value_of_indexed_property(index u32, value dom.JSValue) ! {
	setter := object.hooks_.set_value_of_indexed_property or {
		return error('TypeError: indexed property setter hook is missing')
	}
	setter(index, value)!
}

pub fn (object &PlatformObject) delete_value(name string) !DidDeletionFail {
	deleter := object.hooks_.delete_value or {
		return error('TypeError: named property deleter hook is missing')
	}
	return deleter(name)
}

fn (mut object PlatformObject) ordinary_set(key PropertyKey, value dom.JSValue) bool {
	if current := object.ordinary_get_own_property(key) {
		if !(current.writable or { false }) {
			return false
		}
		return object.ordinary_define_own_property(key, PropertyDescriptor{
			...current
			value: value
		})
	}
	return object.ordinary_define_own_property(key, data_property_descriptor(value, true, true,
		true))
}

// https://webidl.spec.whatwg.org/#legacy-platform-object-set
pub fn (mut object PlatformObject) internal_set(key PropertyKey, value dom.JSValue, receiver_is_this bool) !bool {
	flags := object.legacy_flags_ or { return object.ordinary_set(key, value) }
	if flags.has_global_interface_attribute {
		return object.ordinary_set(key, value)
	}
	if receiver_is_this {
		if flags.has_indexed_property_setter && key.array_index() != none {
			object.invoke_indexed_property_setter(key, value)!
			return true
		}
		if flags.has_named_property_setter && !key.is_symbol() {
			object.invoke_named_property_setter(key.name, value)!
			return true
		}
	}
	return object.ordinary_set(key, value)
}

// https://webidl.spec.whatwg.org/#legacy-platform-object-defineownproperty
pub fn (mut object PlatformObject) internal_define_own_property(key PropertyKey, descriptor PropertyDescriptor) !bool {
	flags := object.legacy_flags_ or { return object.ordinary_define_own_property(key, descriptor) }
	if flags.has_global_interface_attribute {
		return object.ordinary_define_own_property(key, descriptor)
	}
	if flags.supports_indexed_properties && key.array_index() != none {
		if !descriptor.is_data_descriptor() || !flags.has_indexed_property_setter {
			return false
		}
		value := descriptor.value or { dom.js_undefined() }
		object.invoke_indexed_property_setter(key, value)!
		return true
	}
	if flags.supports_named_properties && !key.is_symbol() {
		creating := !object.is_supported_property_name(key.name)
		ordinary_property_exists := object.ordinary_get_own_property(key) != none
		if flags.has_legacy_override_built_ins_interface_attribute || !ordinary_property_exists {
			if !creating && !flags.has_named_property_setter {
				return false
			}
			if flags.has_named_property_setter {
				if !descriptor.is_data_descriptor() {
					return false
				}
				value := descriptor.value or { dom.js_undefined() }
				object.invoke_named_property_setter(key.name, value)!
				return true
			}
		}
	}
	return object.ordinary_define_own_property(key, descriptor)
}

// https://webidl.spec.whatwg.org/#legacy-platform-object-delete
pub fn (mut object PlatformObject) internal_delete(key PropertyKey) !bool {
	flags := object.legacy_flags_ or { return object.ordinary_delete(key) }
	if flags.has_global_interface_attribute {
		return object.ordinary_delete(key)
	}
	if flags.supports_indexed_properties {
		if index := key.array_index() {
			return !object.is_supported_property_index(index)
		}
	}
	if flags.supports_named_properties && object.is_named_property_exposed_on_object(key) {
		if !flags.has_named_property_deleter {
			return false
		}
		result := object.delete_value(key.name)!
		if !flags.named_property_deleter_has_identifier && result == .not_relevant {
			return error('TypeError: unnamed deleter must report whether deletion failed')
		}
		return result != .yes
	}
	return object.ordinary_delete(key)
}

fn (mut object PlatformObject) ordinary_delete(key PropertyKey) bool {
	descriptor := object.ordinary_get_own_property(key) or { return true }
	if !(descriptor.configurable or { false }) {
		return false
	}
	object.ordinary_properties_.delete(key.storage_key())
	for index, existing in object.ordinary_property_order_ {
		if existing == key {
			object.ordinary_property_order_.delete(index)
			break
		}
	}
	return true
}

// https://webidl.spec.whatwg.org/#legacy-platform-object-preventextensions
pub fn (mut object PlatformObject) internal_prevent_extensions() bool {
	if flags := object.legacy_flags_ {
		if !flags.has_global_interface_attribute {
			return false
		}
	}
	object.extensible_ = false
	return true
}

pub fn (object &PlatformObject) is_extensible() bool {
	return object.extensible_
}

pub fn (_ &PlatformObject) eligible_for_own_property_enumeration_fast_path() bool {
	return false
}

fn append_unique_key(mut keys []PropertyKey, key PropertyKey) {
	if key !in keys {
		keys << key
	}
}

// https://webidl.spec.whatwg.org/#legacy-platform-object-ownpropertykeys
pub fn (object &PlatformObject) internal_own_property_keys() []PropertyKey {
	flags := object.legacy_flags_ or { return object.ordinary_property_order_.clone() }
	if flags.has_global_interface_attribute {
		return object.ordinary_property_order_.clone()
	}
	mut keys := []PropertyKey{}
	if flags.supports_indexed_properties {
		mut index := u32(0)
		for object.is_supported_property_index(index) {
			append_unique_key(mut keys, property_key(index.str()))
			if index == 4294967294 {
				break
			}
			index++
		}
	}
	if flags.supports_named_properties {
		for name in object.supported_property_names() {
			key := property_key(name)
			if object.is_named_property_exposed_on_object(key) {
				append_unique_key(mut keys, key)
			}
		}
	}
	for key in object.ordinary_property_order_ {
		if !key.is_symbol() {
			append_unique_key(mut keys, key)
		}
	}
	for key in object.ordinary_property_order_ {
		if key.is_symbol() {
			append_unique_key(mut keys, key)
		}
	}
	return keys
}

// Platform objects return no origin unless a derived object overrides the
// operation. Typed V consumers can supply the override at their object layer.
pub fn (_ &PlatformObject) extract_an_origin() ?dom.Origin {
	return none
}
