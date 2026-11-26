// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn promise_constructor_race(mut vm VM) !Value {
	constructor := vm.this_value()
	capability := new_promise_capability(mut vm, constructor)!
	resolve := constructor.as_object().get(mut vm, PropertyName.from_str('resolve')) or { return reject_promise_capability(mut vm, capability, err) }
	if !resolve.is_function() { return reject_promise_capability(mut vm, capability, vm.throw_error(.type_error, 'Promise resolve must be callable')) }
	mut iterator := get_iterator_sync_value(mut vm, vm.argument(0)) or { return reject_promise_capability(mut vm, capability, err) }
	return perform_promise_race(mut vm, mut iterator, constructor, capability, resolve) or {
		if !is_throw_completion(err) { return err }
		completion := if iterator.done { completion_from_error(err) } else { iterator_close(mut vm, iterator, completion_from_error(err)) }
		return reject_promise_capability(mut vm, capability, completion.release_error())
	}
}

// PromiseConstructor.cpp::perform_promise_race. Consume the full iterable even
// if a custom then settles synchronously; settlement remains the capability's
// responsibility, and an empty iterable leaves the promise pending.
fn perform_promise_race(mut vm VM, mut iterator IteratorRecord, constructor Value, capability &JSPromiseCapability, resolve Value) !Value {
	for {
		vm.consume_execution_budget()!
		step := iterator_step_value(mut vm, mut iterator)!
		if step.done { return capability.promise }
		next := call(mut vm, resolve, constructor, [step.value])!
		then := next.get_with_prototypes(mut vm, PropertyName.from_str('then'), realm_primitive_prototypes())!
		call(mut vm, then, next, [capability.resolve, capability.reject])!
	}
	return capability.promise
}
