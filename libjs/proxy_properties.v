// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Runtime/ProxyObject.cpp 10.5.5–10.5.10. Invariants inspect the target after
// the trap, including changes the trap made before returning.
fn (proxy &ProxyObject) get_own_property(mut vm VM, key PropertyName) !OwnPropertyResult {
	vm.enter_proxy_operation()!
	defer { vm.proxy_operation_depth-- }
	slots := proxy.operands(mut vm)!
	trap := slots.handler.get_method(mut vm, PropertyName.from_str('getOwnPropertyDescriptor'))!
	if trap.is_undefined() { return slots.target.get_own_property_checked(mut vm, key) }
	result := call(mut vm, trap, Value.from_object(slots.handler), [Value.from_object(slots.target), key.to_value(mut vm)])!
	if !result.is_undefined() && !result.is_object() { return vm.throw_error(.type_error, 'Proxy descriptor trap must return an object or undefined') }
	current := slots.target.get_own_property_checked(mut vm, key)!.descriptor
	if result.is_undefined() {
		if descriptor := current {
			if !(descriptor.configurable or { false }) { return vm.throw_error(.type_error, 'Proxy descriptor trap hid a nonconfigurable property') }
			if !slots.target.is_extensible_checked(mut vm)! { return vm.throw_error(.type_error, 'Proxy descriptor trap hid a property of a nonextensible target') }
		}
		return OwnPropertyResult{}
	}
	extensible := slots.target.is_extensible_checked(mut vm)!
	mut descriptor := to_property_descriptor(mut vm, result)!
	descriptor.complete()
	if !is_compatible_property_descriptor(extensible, descriptor, current) { return vm.throw_error(.type_error, 'Proxy descriptor trap returned an incompatible descriptor') }
	if !(descriptor.configurable or { false }) {
		actual := current or { return vm.throw_error(.type_error, 'Proxy descriptor trap invented a nonconfigurable property') }
		if actual.configurable or { false } { return vm.throw_error(.type_error, 'Proxy descriptor trap reported a configurable property as nonconfigurable') }
		if descriptor.is_data_descriptor() && !(descriptor.writable or { false }) && (actual.writable or { false }) { return vm.throw_error(.type_error, 'Proxy descriptor trap reported a writable property as nonwritable') }
	}
	return OwnPropertyResult{descriptor: descriptor}
}

fn (proxy &ProxyObject) define_own_property(mut vm VM, key PropertyName, descriptor PropertyDescriptor) !bool {
	vm.enter_proxy_operation()!
	defer { vm.proxy_operation_depth-- }
	slots := proxy.operands(mut vm)!
	trap := slots.handler.get_method(mut vm, PropertyName.from_str('defineProperty'))!
	mut target := slots.target
	if trap.is_undefined() { return target.internal_define_own_property(mut vm, key, descriptor) }
	descriptor_object := from_property_descriptor(mut vm, descriptor, vm.realm().object_prototype)
	if !call(mut vm, trap, Value.from_object(slots.handler), [Value.from_object(target), key.to_value(mut vm), descriptor_object])!.to_boolean() { return false }
	current := target.get_own_property_checked(mut vm, key)!.descriptor
	extensible := target.is_extensible_checked(mut vm)!
	setting_nonconfigurable := if configurable := descriptor.configurable { !configurable } else { false }
	if actual := current {
		if !is_compatible_property_descriptor(extensible, descriptor, actual) { return vm.throw_error(.type_error, 'Proxy defineProperty trap accepted an incompatible descriptor') }
		if setting_nonconfigurable && (actual.configurable or { false }) { return vm.throw_error(.type_error, 'Proxy defineProperty trap did not make its target property nonconfigurable') }
		if actual.is_data_descriptor() && !(actual.configurable or { false }) && (actual.writable or { false }) {
			if writable := descriptor.writable { if !writable { return vm.throw_error(.type_error, 'Proxy defineProperty trap did not make its target property nonwritable') } }
		}
	} else if !extensible || setting_nonconfigurable {
		return vm.throw_error(.type_error, 'Proxy defineProperty trap cannot add this property to its target')
	}
	return true
}

fn (proxy &ProxyObject) has(mut vm VM, key PropertyName) !bool {
	vm.enter_proxy_operation()!
	defer { vm.proxy_operation_depth-- }
	slots := proxy.operands(mut vm)!
	trap := slots.handler.get_method(mut vm, PropertyName.from_str('has'))!
	if trap.is_undefined() { return slots.target.has_property_checked(mut vm, key) }
	result := call(mut vm, trap, Value.from_object(slots.handler), [Value.from_object(slots.target), key.to_value(mut vm)])!.to_boolean()
	if !result {
		if descriptor := slots.target.get_own_property_checked(mut vm, key)!.descriptor {
			if !(descriptor.configurable or { false }) { return vm.throw_error(.type_error, 'Proxy has trap hid a nonconfigurable property') }
			if !slots.target.is_extensible_checked(mut vm)! { return vm.throw_error(.type_error, 'Proxy has trap hid a property of a nonextensible target') }
		}
	}
	return result
}

fn (proxy &ProxyObject) get(mut vm VM, key PropertyName, receiver Value) !Value {
	vm.enter_proxy_operation()!
	defer { vm.proxy_operation_depth-- }
	slots := proxy.operands(mut vm)!
	trap := slots.handler.get_method(mut vm, PropertyName.from_str('get'))!
	if trap.is_undefined() { return slots.target.internal_get(mut vm, key, receiver) }
	result := call(mut vm, trap, Value.from_object(slots.handler), [Value.from_object(slots.target), key.to_value(mut vm), receiver])!
	if descriptor := slots.target.get_own_property_checked(mut vm, key)!.descriptor {
		if !(descriptor.configurable or { false }) {
			if descriptor.is_data_descriptor() && !(descriptor.writable or { false }) && !same_value(result, descriptor.value or { js_undefined() }) { return vm.throw_error(.type_error, 'Proxy get trap changed an immutable data property') }
			if descriptor.is_accessor_descriptor() && (descriptor.getter or { js_undefined() }).is_undefined() && !result.is_undefined() { return vm.throw_error(.type_error, 'Proxy get trap returned a value for an accessor without a getter') }
		}
	}
	return result
}

fn (proxy &ProxyObject) set(mut vm VM, key PropertyName, value Value, receiver Value) !bool {
	vm.enter_proxy_operation()!
	defer { vm.proxy_operation_depth-- }
	slots := proxy.operands(mut vm)!
	trap := slots.handler.get_method(mut vm, PropertyName.from_str('set'))!
	mut target := slots.target
	if trap.is_undefined() { return target.internal_set(mut vm, key, value, receiver) }
	if !call(mut vm, trap, Value.from_object(slots.handler), [Value.from_object(target), key.to_value(mut vm), value, receiver])!.to_boolean() { return false }
	if descriptor := target.get_own_property_checked(mut vm, key)!.descriptor {
		if !(descriptor.configurable or { false }) {
			if descriptor.is_data_descriptor() && !(descriptor.writable or { false }) && !same_value(value, descriptor.value or { js_undefined() }) { return vm.throw_error(.type_error, 'Proxy set trap changed an immutable data property') }
			if descriptor.is_accessor_descriptor() && (descriptor.setter or { js_undefined() }).is_undefined() { return vm.throw_error(.type_error, 'Proxy set trap accepted an accessor without a setter') }
		}
	}
	return true
}

fn (proxy &ProxyObject) delete_property(mut vm VM, key PropertyName) !bool {
	vm.enter_proxy_operation()!
	defer { vm.proxy_operation_depth-- }
	slots := proxy.operands(mut vm)!
	trap := slots.handler.get_method(mut vm, PropertyName.from_str('deleteProperty'))!
	mut target := slots.target
	if trap.is_undefined() { return target.delete_checked(mut vm, key) }
	result := call(mut vm, trap, Value.from_object(slots.handler), [Value.from_object(target), key.to_value(mut vm)])!.to_boolean()
	if !result { return false }
	if descriptor := target.get_own_property_checked(mut vm, key)!.descriptor {
		if !(descriptor.configurable or { false }) { return vm.throw_error(.type_error, 'Proxy deleteProperty trap hid a nonconfigurable property') }
		if !target.is_extensible_checked(mut vm)! { return vm.throw_error(.type_error, 'Proxy deleteProperty trap hid a property of a nonextensible target') }
	}
	return true
}
