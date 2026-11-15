// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Runtime/ProxyObject.cpp 10.5.1–10.5.4.
fn (proxy &ProxyObject) get_prototype_of(mut vm VM) !PrototypeResult {
	vm.enter_proxy_operation()!
	defer { vm.proxy_operation_depth-- }
	slots := proxy.operands(mut vm)!
	trap := slots.handler.get_method(mut vm, PropertyName.from_str('getPrototypeOf'))!
	if trap.is_undefined() { return slots.target.get_prototype_of_checked(mut vm) }
	result := call(mut vm, trap, Value.from_object(slots.handler), [Value.from_object(slots.target)])!
	if !result.is_object() && !result.is_null() { return vm.throw_error(.type_error, 'Proxy getPrototypeOf trap must return an object or null') }
	if !slots.target.is_extensible_checked(mut vm)! {
		actual := slots.target.get_prototype_of_checked(mut vm)!.prototype
		if !same_value(result, proxy_prototype_value(actual)) { return vm.throw_error(.type_error, 'Proxy getPrototypeOf trap disagrees with a nonextensible target') }
	}
	return PrototypeResult{prototype: if result.is_object() { ?&Object(result.as_object()) } else { none }}
}

fn (proxy &ProxyObject) set_prototype_of(mut vm VM, prototype ?&Object) !bool {
	vm.enter_proxy_operation()!
	defer { vm.proxy_operation_depth-- }
	slots := proxy.operands(mut vm)!
	trap := slots.handler.get_method(mut vm, PropertyName.from_str('setPrototypeOf'))!
	mut target := slots.target
	if trap.is_undefined() { return target.set_prototype_of_checked(mut vm, prototype) }
	result := call(mut vm, trap, Value.from_object(slots.handler), [Value.from_object(target), proxy_prototype_value(prototype)])!.to_boolean()
	if !result { return false }
	if !target.is_extensible_checked(mut vm)! {
		actual := target.get_prototype_of_checked(mut vm)!.prototype
		if !same_value(proxy_prototype_value(prototype), proxy_prototype_value(actual)) { return vm.throw_error(.type_error, 'Proxy setPrototypeOf trap disagrees with a nonextensible target') }
	}
	return true
}

fn (proxy &ProxyObject) is_extensible(mut vm VM) !bool {
	vm.enter_proxy_operation()!
	defer { vm.proxy_operation_depth-- }
	slots := proxy.operands(mut vm)!
	trap := slots.handler.get_method(mut vm, PropertyName.from_str('isExtensible'))!
	if trap.is_undefined() { return slots.target.is_extensible_checked(mut vm) }
	result := call(mut vm, trap, Value.from_object(slots.handler), [Value.from_object(slots.target)])!.to_boolean()
	if result != slots.target.is_extensible_checked(mut vm)! { return vm.throw_error(.type_error, 'Proxy isExtensible trap disagrees with its target') }
	return result
}

fn (proxy &ProxyObject) prevent_extensions(mut vm VM) !bool {
	vm.enter_proxy_operation()!
	defer { vm.proxy_operation_depth-- }
	slots := proxy.operands(mut vm)!
	trap := slots.handler.get_method(mut vm, PropertyName.from_str('preventExtensions'))!
	mut target := slots.target
	if trap.is_undefined() { return target.prevent_extensions_checked(mut vm) }
	result := call(mut vm, trap, Value.from_object(slots.handler), [Value.from_object(target)])!.to_boolean()
	if result && target.is_extensible_checked(mut vm)! { return vm.throw_error(.type_error, 'Proxy preventExtensions trap left its target extensible') }
	return result
}
