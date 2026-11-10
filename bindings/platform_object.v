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
import libjs

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

fn property_key_to_utf16_fly_string(key PropertyKey) string {
	// V strings are UTF-8, but unlike the old C++ conversion path this keeps the
	// complete scalar sequence instead of narrowing it through an ASCII view.
	return key.name
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
		value: value
		writable: writable
		enumerable: enumerable
		configurable: configurable
	}
}

pub fn accessor_property_descriptor(enumerable bool, configurable bool) PropertyDescriptor {
	return PropertyDescriptor{
		enumerable: enumerable
		configurable: configurable
		accessor: true
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

pub enum NamedPropertyDeletionResult {
	not_relevant
	did_not_fail
	did_fail
}

pub type IndexedPropertyGetter = fn (&WrapperWorld, &html.ScriptingRealm, u32) ?dom.JSValue

pub type NamedPropertyGetter = fn (&WrapperWorld, &html.ScriptingRealm, string) dom.JSValue

pub type SupportedPropertyNamesGetter = fn () []string

pub type SupportedPropertyNameChecker = fn (string) bool

pub type IndexedPropertySetter = fn (&html.ScriptingRealm, u32, dom.JSValue) !

pub type NamedPropertySetter = fn (&html.ScriptingRealm, string, dom.JSValue) !

pub type NamedPropertyDeleter = fn (string) !NamedPropertyDeletionResult

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
	realm_                          &html.ScriptingRealm
	wrappable_impl_                 ?&Wrappable
	prototype_                      ?&PlatformObject
	interface_name_                 string
	implemented_interfaces_         []string
	named_properties_object_        bool
	legacy_flags_                   ?LegacyPlatformObjectFlags
	hooks_                          LegacyPlatformObjectHooks
	ordinary_properties_            map[string]PropertyDescriptor
	ordinary_property_order_        []PropertyKey
	extensible_                     bool = true
	requires_slow_add_own_property_ bool = true
}

pub fn PlatformObject.create(realm &html.ScriptingRealm) &PlatformObject {
	return &PlatformObject{
		realm_: realm
	}
}

pub fn PlatformObject.create_with_prototype(prototype &PlatformObject) &PlatformObject {
	return &PlatformObject{
		realm_: prototype.realm_
		prototype_: prototype
	}
}

pub fn PlatformObject.create_with_wrappable(realm &html.ScriptingRealm, implementation &Wrappable) &PlatformObject {
	return &PlatformObject{
		realm_: realm
		wrappable_impl_: implementation
	}
}

pub fn PlatformObject.create_with_prototype_and_wrappable(prototype &PlatformObject, implementation &Wrappable) &PlatformObject {
	return &PlatformObject{
		realm_: prototype.realm_
		prototype_: prototype
		wrappable_impl_: implementation
	}
}

pub fn (object &PlatformObject) realm() &html.ScriptingRealm {
	return object.realm_
}

pub fn (mut object PlatformObject) set_wrappable_impl(implementation &Wrappable) {
	object.wrappable_impl_ = implementation
}

pub fn (object &PlatformObject) wrappable_impl() ?&Wrappable {
	return object.wrappable_impl_
}

pub fn (_ &PlatformObject) wrapped_implementation_offset() uint {
	// V does not expose stable ABI field offsets. The wrapper bridge accesses the
	// implementation through wrappable_impl() instead.
	return 0
}

pub fn (mut object PlatformObject) set_prototype(prototype ?&PlatformObject) {
	object.prototype_ = prototype
}

pub fn (object &PlatformObject) prototype() ?&PlatformObject {
	return object.prototype_
}

fn same_platform_object(left ?&PlatformObject, right ?&PlatformObject) bool {
	left_object := left or { return right == none }
	right_object := right or { return false }
	return voidptr(left_object) == voidptr(right_object)
}

pub fn (mut object PlatformObject) internal_set_prototype_of(prototype ?&PlatformObject) bool {
	old_prototype := object.prototype_
	object.prototype_ = prototype
	if !same_platform_object(old_prototype, object.prototype_)
		&& host_defined_for_realm(object.realm_) != none {
		if mut wrappable := object.wrappable_impl_ {
			preserve_wrapper(mut wrappable, object)
		}
	}
	return true
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
	if implementation := object.wrappable_impl_ {
		return implementation.implements_interface(name)
	}
	return name in object.implemented_interfaces_
}

pub fn (object &PlatformObject) interface_name() !string {
	if implementation := object.wrappable_impl_ {
		return implementation.interface_name()
	}
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

pub fn (object &PlatformObject) is_legacy_platform_object() bool {
	return object.legacy_flags_ != none
}

pub fn (object &PlatformObject) is_cacheable_for_property_absence() bool {
	return !object.is_legacy_platform_object()
}

pub fn (object &PlatformObject) is_cacheable_for_inherited_property() bool {
	flags := object.legacy_flags_ or { return true }
	if !flags.supports_named_properties
		|| !flags.has_legacy_override_built_ins_interface_attribute {
		return true
	}
	implementation := object.wrappable_impl_ or { return false }
	if !implementation.implements_interface('Document') {
		return false
	}
	host_defined_for_realm(object.realm_) or { return false }
	return host_defined_wrapper_world(object.realm_).is_main_world()
}

pub fn (object &PlatformObject) requires_slow_add_own_property() bool {
	return object.requires_slow_add_own_property_
}

pub fn (mut object PlatformObject) clear_requires_slow_add_own_property() {
	object.requires_slow_add_own_property_ = false
}

fn js_values_same(left dom.JSValue, right dom.JSValue) bool {
	if left.kind != right.kind {
		return false
	}
	return match left.kind {
		.undefined, .null_ { true }
		.boolean { left.boolean_data == right.boolean_data }
		.number { libjs.same_value(libjs.Value.from_f64(left.number_data), libjs.Value.from_f64(right.number_data)) }
		.string { (left.string_utf16_ or { libjs.utf16_string(left.string_data) }) == (right.string_utf16_ or { libjs.utf16_string(right.string_data) }) }
		.object { left.object_data == right.object_data }
		.runtime_value {
			// Source SameValue cannot run author code or throw. Missing owner
			// hooks are an internal invariant failure, never invented equality.
			left.native_same_value(right) or { panic(err) }
		}
	}
}

fn (object &PlatformObject) ordinary_get_own_property(key PropertyKey) ?PropertyDescriptor {
	return object.ordinary_properties_[key.storage_key()] or { none }
}

fn (mut object PlatformObject) base_ordinary_define_own_property(key PropertyKey, descriptor PropertyDescriptor) bool {
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

// Defines an ordinary property and preserves a newly-expanded wrapper so the
// expando remains alive for as long as its implementation object.
pub fn ordinary_define_own_property_and_preserve_wrapper_if_needed(mut object PlatformObject, key PropertyKey, descriptor PropertyDescriptor) bool {
	already_had_own_property := object.ordinary_get_own_property(key) != none
	result := object.base_ordinary_define_own_property(key, descriptor)
	if result && !already_had_own_property && host_defined_for_realm(object.realm_) != none {
		if mut wrappable := object.wrappable_impl_ {
			preserve_wrapper(mut wrappable, object)
			if !object.is_legacy_platform_object() {
				object.clear_requires_slow_add_own_property()
			}
		}
	}
	return result
}

pub fn (mut object PlatformObject) define_ordinary_property(key PropertyKey, descriptor PropertyDescriptor) bool {
	return ordinary_define_own_property_and_preserve_wrapper_if_needed(mut object, key, descriptor)
}

fn (object &PlatformObject) item_value(wrapper_world &WrapperWorld, realm &html.ScriptingRealm, index u32) ?dom.JSValue {
	getter := object.hooks_.item_value or { return none }
	return getter(wrapper_world, realm, index)
}

fn (object &PlatformObject) named_item_value(wrapper_world &WrapperWorld, realm &html.ScriptingRealm, name string) dom.JSValue {
	getter := object.hooks_.named_item_value or { return dom.js_undefined() }
	return getter(wrapper_world, realm, name)
}

fn (object &PlatformObject) supported_property_names() []string {
	if getter := object.hooks_.supported_property_names {
		return getter()
	}
	if implementation := object.wrappable_impl_ {
		return implementation.supported_property_names()
	}
	return []
}

fn (object &PlatformObject) is_supported_property_name(name string) bool {
	if checker := object.hooks_.is_supported_property_name {
		return checker(name)
	}
	if implementation := object.wrappable_impl_ {
		return implementation.is_supported_property_name(name)
	}
	return name in object.supported_property_names()
}

fn (object &PlatformObject) is_supported_property_index(index u32) bool {
	if host_defined_for_realm(object.realm_) == none {
		return false
	}
	return object.item_value(host_defined_wrapper_world(object.realm_), object.realm_, index) != none
}

// https://webidl.spec.whatwg.org/#dfn-named-property-visibility
pub fn (object &PlatformObject) is_named_property_exposed_on_object(key PropertyKey) bool {
	if key.is_symbol() || !object.is_supported_property_name(key.name) {
		return false
	}
	return object.is_supported_named_property_exposed_on_object(key)
}

// Own-key enumeration already obtained these names from supported_property_names.
// Keep the visibility checks without rebuilding that list for each name.
fn (object &PlatformObject) is_supported_named_property_exposed_on_object(key PropertyKey) bool {
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
	wrapper_world := host_defined_wrapper_world(object.realm_)
	mut ignore_named := ignore_named_properties
	if flags.supports_indexed_properties {
		if index := key.array_index() {
			if value := object.item_value(wrapper_world, object.realm_, index) {
				return data_property_descriptor(value, flags.has_indexed_property_setter, true, true)
			}
			ignore_named = true
		}
	}
	if flags.supports_named_properties && !ignore_named
		&& object.is_named_property_exposed_on_object(key) {
		return data_property_descriptor(object.named_item_value(wrapper_world, object.realm_, property_key_to_utf16_fly_string(key)), flags.has_named_property_setter, !flags.has_legacy_unenumerable_named_properties_interface_attribute, true)
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
			object.set_value_of_new_indexed_property(object.realm_, index, value)!
			return
		}
		object.set_value_of_existing_indexed_property(object.realm_, index, value)!
		return
	}
	object.set_value_of_indexed_property(object.realm_, index, value)!
}

fn (object &PlatformObject) invoke_named_property_setter(name string, value dom.JSValue) ! {
	flags := object.legacy_flags_ or {
		return error('TypeError: object is not a legacy platform object')
	}

	creating := !object.is_supported_property_name(name)
	if !flags.named_property_setter_has_identifier {
		if creating {
			object.set_value_of_new_named_property(object.realm_, name, value)!
			return
		}
		object.set_value_of_existing_named_property(object.realm_, name, value)!
		return
	}
	object.set_value_of_named_property(object.realm_, name, value)!
}

pub fn (object &PlatformObject) set_value_of_new_named_property(realm &html.ScriptingRealm, name string, value dom.JSValue) ! {
	setter := object.hooks_.set_value_of_new_named_property or {
		return error('TypeError: named property setter hook is missing')
	}
	setter(realm, name, value)!
}

pub fn (object &PlatformObject) set_value_of_existing_named_property(realm &html.ScriptingRealm, name string, value dom.JSValue) ! {
	setter := object.hooks_.set_value_of_existing_named_property or {
		return error('TypeError: named property setter hook is missing')
	}
	setter(realm, name, value)!
}

pub fn (object &PlatformObject) set_value_of_named_property(realm &html.ScriptingRealm, name string, value dom.JSValue) ! {
	setter := object.hooks_.set_value_of_named_property or {
		return error('TypeError: named property setter hook is missing')
	}
	setter(realm, name, value)!
}

pub fn (object &PlatformObject) set_value_of_new_indexed_property(realm &html.ScriptingRealm, index u32, value dom.JSValue) ! {
	setter := object.hooks_.set_value_of_new_indexed_property or {
		return error('TypeError: indexed property setter hook is missing')
	}
	setter(realm, index, value)!
}

pub fn (object &PlatformObject) set_value_of_existing_indexed_property(realm &html.ScriptingRealm, index u32, value dom.JSValue) ! {
	setter := object.hooks_.set_value_of_existing_indexed_property or {
		return error('TypeError: indexed property setter hook is missing')
	}
	setter(realm, index, value)!
}

pub fn (object &PlatformObject) set_value_of_indexed_property(realm &html.ScriptingRealm, index u32, value dom.JSValue) ! {
	setter := object.hooks_.set_value_of_indexed_property or {
		return error('TypeError: indexed property setter hook is missing')
	}
	setter(realm, index, value)!
}

pub fn (object &PlatformObject) delete_value(name string) !NamedPropertyDeletionResult {
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
		return ordinary_define_own_property_and_preserve_wrapper_if_needed(mut object, key, PropertyDescriptor{
			...current
			value: value
		})
	}
	return ordinary_define_own_property_and_preserve_wrapper_if_needed(mut object, key, data_property_descriptor(value, true, true, true))
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
	flags := object.legacy_flags_ or {
		return ordinary_define_own_property_and_preserve_wrapper_if_needed(mut object, key, descriptor)
	}
	if flags.has_global_interface_attribute {
		return ordinary_define_own_property_and_preserve_wrapper_if_needed(mut object, key, descriptor)
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
	return ordinary_define_own_property_and_preserve_wrapper_if_needed(mut object, key, descriptor)
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
		return result != .did_fail
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
	was_extensible := object.extensible_
	object.extensible_ = false
	if was_extensible && host_defined_for_realm(object.realm_) != none {
		if mut wrappable := object.wrappable_impl_ {
			preserve_wrapper(mut wrappable, object)
		}
	}
	return true
}

pub fn (object &PlatformObject) is_extensible() bool {
	return object.extensible_
}

pub fn (_ &PlatformObject) eligible_for_own_property_enumeration_fast_path() bool {
	return false
}

fn append_unique_key(mut keys []PropertyKey, mut seen map[string]bool, key PropertyKey) {
	storage_key := key.storage_key()
	if storage_key !in seen {
		seen[storage_key] = true
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
	mut seen := map[string]bool{}
	if flags.supports_indexed_properties {
		mut index := u32(0)
		for object.is_supported_property_index(index) {
			append_unique_key(mut keys, mut seen, property_key(index.str()))
			if index == 4294967294 {
				break
			}
			index++
		}
	}
	if flags.supports_named_properties {
		for name in object.supported_property_names() {
			key := property_key(name)
			if object.is_supported_named_property_exposed_on_object(key) {
				append_unique_key(mut keys, mut seen, key)
			}
		}
	}
	for key in object.ordinary_property_order_ {
		if !key.is_symbol() {
			append_unique_key(mut keys, mut seen, key)
		}
	}
	for key in object.ordinary_property_order_ {
		if key.is_symbol() {
			append_unique_key(mut keys, mut seen, key)
		}
	}
	return keys
}

// Platform objects return no origin unless a derived object overrides the
// operation. Typed V consumers can supply the override at their object layer.
pub fn (object &PlatformObject) extract_an_origin() ?dom.Origin {
	implementation := object.wrappable_impl_ or { return none }
	return implementation.extract_an_origin()
}

// Mirrors PlatformObject::finalize. V's collector does not invoke this hook,
// so embedders call it when releasing a translated wrapper explicitly.
pub fn (mut object PlatformObject) finalize() {
	mut implementation := object.wrappable_impl_ or { return }
	if host_defined_for_realm(object.realm_) == none {
		return
	}
	mut world := unsafe { &WrapperWorld(host_defined_wrapper_world(object.realm_)) }
	world.clear_wrapper(mut implementation, object)
}
