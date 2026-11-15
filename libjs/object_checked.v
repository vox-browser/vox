// SPDX-License-Identifier: BSD-2-Clause
module libjs

// The original nonthrowing Object helpers inspect concrete engine records.
// Script-visible internal methods use these checked entry points so exotic
// operations can complete abruptly. Wrappers keep absence distinct from throw.
pub struct OwnPropertyResult {
pub:
	descriptor ?PropertyDescriptor
}

pub struct PrototypeResult {
pub:
	prototype ?&Object
}

pub fn (object &Object) get_own_property_checked(mut vm VM, key PropertyName) !OwnPropertyResult {
	if proxy := object.proxy_object { return proxy.get_own_property(mut vm, key) }
	return OwnPropertyResult{descriptor: object.internal_get_own_property(key)}
}

pub fn (object &Object) own_property_keys_checked(mut vm VM) ![]PropertyName {
	if proxy := object.proxy_object { return proxy.own_keys(mut vm) }
	return object.own_property_keys()
}

pub fn (object &Object) has_own_property_checked(mut vm VM, key PropertyName) !bool {
	return object.get_own_property_checked(mut vm, key)!.descriptor != none
}

pub fn (object &Object) has_property_checked(mut vm VM, key PropertyName) !bool {
	if proxy := object.proxy_object { return proxy.has(mut vm, key) }
	mut current := ?&Object(object)
	for {
		holder := current or { return false }
		vm.consume_execution_budget()!
		if proxy := holder.proxy_object { return proxy.has(mut vm, key) }
		if array := holder.typed_array {
			if index := typed_array_property_index(key) { return is_valid_integer_index(array, index) }
		}
		if holder.internal_get_own_property(key) != none { return true }
		current = holder.prototype
	}
	return false
}

pub fn (object &Object) get_prototype_of_checked(mut vm VM) !PrototypeResult {
	if proxy := object.proxy_object { return proxy.get_prototype_of(mut vm) }
	return PrototypeResult{prototype: object.internal_get_prototype_of()}
}

pub fn (mut object Object) set_prototype_of_checked(mut vm VM, prototype ?&Object) !bool {
	if proxy := object.proxy_object { return proxy.set_prototype_of(mut vm, prototype) }
	return object.internal_set_prototype_of(prototype)
}

pub fn (object &Object) is_extensible_checked(mut vm VM) !bool {
	if proxy := object.proxy_object { return proxy.is_extensible(mut vm) }
	return object.internal_is_extensible()
}

pub fn (mut object Object) prevent_extensions_checked(mut vm VM) !bool {
	if proxy := object.proxy_object { return proxy.prevent_extensions(mut vm) }
	return object.internal_prevent_extensions()
}

pub fn (mut object Object) delete_checked(mut vm VM, key PropertyName) !bool {
	if proxy := object.proxy_object { return proxy.delete_property(mut vm, key) }
	return object.internal_delete(key)
}

pub fn (object &Object) test_integrity_level_checked(mut vm VM, level IntegrityLevel) !bool {
	if object.is_extensible_checked(mut vm)! { return false }
	for key in object.own_property_keys_checked(mut vm)! {
		if descriptor := object.get_own_property_checked(mut vm, key)!.descriptor {
			if descriptor.configurable or { false } { return false }
			if level == .frozen && descriptor.is_data_descriptor() && (descriptor.writable or { false }) { return false }
		}
	}
	return true
}
