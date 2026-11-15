// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Runtime/ProxyObject.{h,cpp}. Target and handler are genuinely nullable: a
// revoked proxy releases both while retaining its initial callable shape.
@[heap]
pub struct ProxyObject {
pub:
	object &Object
mut:
	target ?&Object
	handler ?&Object
}

struct ProxyOperands {
	target &Object
	handler &Object
}

pub fn ProxyObject.create(realm &Realm, target &Object, handler &Object) &ProxyObject {
	mut object := Object.create(realm, none)
	object.class_name = 'Proxy'
	proxy := &ProxyObject{object: object, target: target, handler: handler}
	object.proxy_object = proxy
	if target.callable != none { object.callable = FunctionObject(proxy) }
	if Value.from_object(target).is_constructor() { object.constructor = ConstructorFunction(proxy) }
	return proxy
}

fn (proxy &ProxyObject) operands(mut vm VM) !ProxyOperands {
	target := proxy.target or { return vm.throw_error(.type_error, 'Cannot perform an operation on a revoked Proxy') }
	handler := proxy.handler or { panic('Live Proxy has no handler') }
	return ProxyOperands{target: target, handler: handler}
}

pub fn (mut proxy ProxyObject) revoke() {
	proxy.target = none
	proxy.handler = none
}

// A VM-local bound also catches tail-recursive transparent forwarding, whose
// recursion does not allocate bytecode frames. Each operation charges budget.
fn (mut vm VM) enter_proxy_operation() ! {
	vm.consume_execution_budget()!
	if vm.proxy_operation_depth >= 128 || vm.did_reach_stack_space_limit() {
		return vm.throw_error_type(.internal_error, .call_stack_size_exceeded)
	}
	vm.proxy_operation_depth++
}

fn proxy_prototype_value(prototype ?&Object) Value {
	if object := prototype { return Value.from_object(object) }
	return js_null()
}

pub fn (proxy &ProxyObject) realm() ?&Realm { return none }
pub fn (proxy &ProxyObject) name_for_call_stack() Utf16String { return utf16_string('(Proxy)') }

pub fn (mut proxy ProxyObject) internal_call(mut vm VM, this_value Value, arguments []Value) !Value {
	vm.enter_proxy_operation()!
	defer { vm.proxy_operation_depth-- }
	slots := proxy.operands(mut vm)!
	trap := slots.handler.get_method(mut vm, PropertyName.from_str('apply'))!
	if trap.is_undefined() { return call(mut vm, Value.from_object(slots.target), this_value, arguments) }
	array := ArrayObject.create_from(mut vm, vm.realm(), arguments, vm.realm().array_prototype_record())!
	return call(mut vm, trap, Value.from_object(slots.handler), [Value.from_object(slots.target), this_value, Value.from_object(array.object)])
}

pub fn (mut proxy ProxyObject) internal_construct(mut vm VM, arguments []Value, new_target &Object) !&Object {
	vm.enter_proxy_operation()!
	defer { vm.proxy_operation_depth-- }
	slots := proxy.operands(mut vm)!
	trap := slots.handler.get_method(mut vm, PropertyName.from_str('construct'))!
	if trap.is_undefined() { return construct(mut vm, Value.from_object(slots.target), arguments, new_target) }
	array := ArrayObject.create_from(mut vm, vm.realm(), arguments, vm.realm().array_prototype_record())!
	result := call(mut vm, trap, Value.from_object(slots.handler), [Value.from_object(slots.target), Value.from_object(array.object), Value.from_object(new_target)])!
	if !result.is_object() { return vm.throw_error(.type_error, 'Proxy construct trap must return an object') }
	return result.as_object()
}
