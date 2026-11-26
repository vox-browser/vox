// SPDX-License-Identifier: BSD-2-Clause
module libjs

// PromisePrototype.cpp::finally. Species and the receiver's then remain
// observable; cleanup is assimilated through the intrinsic PromiseResolve
// operation, independently of an author-replaced constructor.resolve method.
fn promise_prototype_finally(mut vm VM) !Value {
	receiver := vm.this_value()
	if !receiver.is_object() { return vm.throw_error(.type_error, 'Promise finally requires an object') }
	constructor := species_constructor(mut vm, receiver.as_object(), vm.realm().promise_constructor_record())!
	callback := vm.argument(0)
	mut fulfilled, mut rejected := callback, callback
	if callback.is_function() {
		fulfilled = create_finally_handler(mut vm, constructor, callback, false)
		rejected = create_finally_handler(mut vm, constructor, callback, true)
	}
	then := receiver.as_object().get(mut vm, PropertyName.from_str('then'))!
	return call(mut vm, then, receiver, [fulfilled, rejected])
}

fn create_finally_handler(mut vm VM, constructor &Object, callback Value, rejects bool) Value {
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [constructor, callback, rejects] (mut vm VM) !Value {
		original := vm.argument(0)
		result := call(mut vm, callback, js_undefined(), []Value{})!
		promise := promise_resolve(mut vm, Value.from_object(constructor), result)!
		thunk := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [original, rejects] (mut vm VM) !Value {
			if rejects { return throw_completion(original) }
			return original
		}, 0, PropertyName.from_str(''), none).object
		then := promise.get_with_prototypes(mut vm, PropertyName.from_str('then'), realm_primitive_prototypes())!
		return call(mut vm, then, promise, [Value.from_object(thunk)])
	}, 1, PropertyName.from_str(''), none).object
	return Value.from_object(function)
}
