// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Encode UTF-16 units without replacement-decoding lone surrogates.
fn property_name_identity(key PropertyName) string {
	if key.is_symbol() { return 'y:${voidptr(key.as_symbol())}' }
	if key.is_number() { return 'n:${key.number}' }
	return 's:${key.as_string().data}'
}

// Runtime/ProxyObject.cpp 10.5.11. Preserve trap order rather than applying
// ordinary integer-key sorting; symbols retain identity, including equal names.
fn (proxy &ProxyObject) own_keys(mut vm VM) ![]PropertyName {
	vm.enter_proxy_operation()!
	defer { vm.proxy_operation_depth-- }
	slots := proxy.operands(mut vm)!
	trap := slots.handler.get_method(mut vm, PropertyName.from_str('ownKeys'))!
	if trap.is_undefined() { return slots.target.own_property_keys_checked(mut vm) }
	result := call(mut vm, trap, Value.from_object(slots.handler), [Value.from_object(slots.target)])!
	if !result.is_object() { return vm.throw_error(.type_error, 'Proxy ownKeys trap must return an object') }
	array := result.as_object()
	length := length_of_array_like(mut vm, array)!
	mut keys := []PropertyName{}
	mut seen := map[string]bool{}
	mut duplicates := false
	for index := u64(0); index < length; index++ {
		vm.consume_execution_budget()!
		value := array.get(mut vm, array_index_key(index))!
		if !value.is_string() && !value.is_symbol() { return vm.throw_error(.type_error, 'Proxy ownKeys trap entries must be strings or symbols') }
		key := value.to_property_key(mut vm)!
		// Canonical PropertyName equality distinguishes symbols from strings and
		// canonical indices from other decimal-looking strings.
		identity := property_name_identity(key)
		if seen[identity] { duplicates = true }
		seen[identity] = true
		keys << key
	}
	// CreateListFromArrayLike must finish (or throw) before duplicate checking.
	if duplicates { return vm.throw_error(.type_error, 'Proxy ownKeys trap returned duplicate keys') }
	extensible := slots.target.is_extensible_checked(mut vm)!
	target_keys := slots.target.own_property_keys_checked(mut vm)!
	mut required := []PropertyName{}
	for key in target_keys {
		vm.consume_execution_budget()!
		if descriptor := slots.target.get_own_property_checked(mut vm, key)!.descriptor {
			if !(descriptor.configurable or { false }) { required << key }
		}
	}
	for key in required {
		if !seen[property_name_identity(key)] { return vm.throw_error(.type_error, 'Proxy ownKeys trap omitted a nonconfigurable property') }
	}
	if !extensible {
		for key in target_keys {
			if !seen[property_name_identity(key)] { return vm.throw_error(.type_error, 'Proxy ownKeys trap omitted a property of a nonextensible target') }
		}
		if keys.len != target_keys.len { return vm.throw_error(.type_error, 'Proxy ownKeys trap added a key to a nonextensible target') }
	}
	return keys
}
