// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn legacy_property_name(key PropertyName) Utf16String {
	return if key.is_number() { utf16_string(key.number.str()) } else { key.as_string() }
}

// WebIDL named-property visibility uses ordinary own storage on the receiver,
// then checked prototype operations so author Proxy traps can throw or mutate.
fn (object &Object) legacy_named_property_exposed(mut vm VM, key PropertyName) !bool {
	if key.is_symbol() { return false }
	legacy := object.legacy_platform_object or { return false }
	native := legacy.named_properties or { return false }
	if !native.is_supported_property_name(legacy_property_name(key)) { return false }
	if object.find_own_property(key) >= 0 { return false }
	if legacy.legacy_override_builtins { return true }
	mut prototype := object.get_prototype_of_checked(mut vm)!.prototype
	for {
		holder := prototype or { break }
		vm.consume_execution_budget()!
		is_named_properties_object := if metadata := holder.legacy_platform_object { metadata.is_named_properties_object } else { false }
		if !is_named_properties_object && holder.has_own_property_checked(mut vm, key)! { return false }
		prototype = holder.get_prototype_of_checked(mut vm)!.prototype
	}
	return true
}

fn (object &Object) legacy_get_own_property_checked(mut vm VM, key PropertyName) !OwnPropertyResult {
	legacy := object.legacy_platform_object or { return OwnPropertyResult{descriptor: object.internal_get_own_property(key)} }
	// A missing array index cannot fall through to a named property.
	if !(key.is_number() && legacy.indexed_properties != none) {
		if native := legacy.named_properties {
			if object.legacy_named_property_exposed(mut vm, key)! {
				return OwnPropertyResult{descriptor: PropertyDescriptor{
					value: native.named_property_value(legacy_property_name(key))
					writable: false
					enumerable: !legacy.legacy_unenumerable_named_properties
					configurable: true
				}}
			}
		}
	}
	return OwnPropertyResult{descriptor: object.internal_get_own_property(key)}
}

// These families have no named setter. Existing ordinary own properties can
// still be redefined unless LegacyOverrideBuiltIns selects the native name.
fn (object &Object) legacy_named_definition_allowed(key PropertyName) bool {
	if key.is_symbol() { return true }
	legacy := object.legacy_platform_object or { return true }
	native := legacy.named_properties or { return true }
	if !legacy.legacy_override_builtins && object.find_own_property(key) >= 0 { return true }
	return !native.is_supported_property_name(legacy_property_name(key))
}

fn (object &Object) legacy_named_property_keys(mut vm VM) ![]PropertyName {
	legacy := object.legacy_platform_object or { return object.own_property_keys() }
	native := legacy.named_properties or { return object.own_property_keys() }
	mut keys := if host := object.host_properties { host.own_property_keys() } else { []PropertyName{} }
	mut seen := map[string]bool{}
	for key in keys { vm.consume_execution_budget()!; seen[property_name_identity(key)] = true }
	for name in native.supported_property_names() {
		vm.consume_execution_budget()!
		key := PropertyName.from_utf16(name)
		if seen[property_name_identity(key)] { continue }
		if object.legacy_named_property_exposed(mut vm, key)! {
			keys << key; seen[property_name_identity(key)] = true
		}
	}
	// Legacy keys use native indices, visible names, ordinary strings, symbols.
	for symbols in [false, true] {
		for property in object.properties {
			vm.consume_execution_budget()!
			key := property.key
			if key.is_symbol() != symbols { continue }
			if key.is_symbol() && key.as_symbol().is_private() { continue }
			identity := property_name_identity(key)
			if !seen[identity] { keys << key; seen[identity] = true }
		}
	}
	return keys
}
