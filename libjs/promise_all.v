// SPDX-License-Identifier: BSD-2-Clause
module libjs

@[heap]
struct PromiseAllState {
	capability &JSPromiseCapability
mut:
	values []Value
	remaining u64 = 1
}

@[heap]
struct PromiseAllElement {
	state &PromiseAllState
	index int
mut:
	already_called bool
}

fn reject_promise_capability(mut vm VM, capability &JSPromiseCapability, failure IError) !Value {
	if !is_throw_completion(failure) { return failure }
	call(mut vm, capability.reject, js_undefined(), [thrown_value(failure)])!
	return capability.promise
}

// PromiseConstructor.cpp::{all,perform_promise_all}. Custom constructors,
// constructor.resolve and then are observable. IteratorClose runs only for an
// abrupt completion after iterator creation that has not already marked done.
fn promise_constructor_all(mut vm VM) !Value {
	constructor := vm.this_value()
	capability := new_promise_capability(mut vm, constructor)!
	resolve := constructor.as_object().get(mut vm, PropertyName.from_str('resolve')) or { return reject_promise_capability(mut vm, capability, err) }
	if !resolve.is_function() { return reject_promise_capability(mut vm, capability, vm.throw_error(.type_error, 'Promise resolve must be callable')) }
	mut iterator := get_iterator_sync_value(mut vm, vm.argument(0)) or { return reject_promise_capability(mut vm, capability, err) }
	return perform_promise_all(mut vm, mut iterator, constructor, capability, resolve) or {
		if !is_throw_completion(err) { return err }
		completion := if iterator.done { completion_from_error(err) } else { iterator_close(mut vm, iterator, completion_from_error(err)) }
		return reject_promise_capability(mut vm, capability, completion.release_error())
	}
}

fn perform_promise_all(mut vm VM, mut iterator IteratorRecord, constructor Value, capability &JSPromiseCapability, resolve Value) !Value {
	mut state := &PromiseAllState{capability: capability}
	for {
		vm.consume_execution_budget()!
		step := iterator_step_value(mut vm, mut iterator)!
		if step.done {
			state.remaining--
			if state.remaining == 0 {
				array := ArrayObject.create_from(mut vm, vm.realm(), state.values, vm.realm().array_prototype_record())!.object
				call(mut vm, capability.resolve, js_undefined(), [Value.from_object(array)])!
			}
			return capability.promise
		}
		index := state.values.len
		if u64(index) >= 9007199254740991 { return vm.throw_error(.type_error, 'Promise.all index exceeds the safe integer range') }
		state.values << js_undefined()
		next := call(mut vm, resolve, constructor, [step.value])!
		record := &PromiseAllElement{state: state, index: index}
		fulfilled := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [record] (mut vm VM) !Value {
			mut element := unsafe { &PromiseAllElement(record) }
			if element.already_called { return js_undefined() }
			element.already_called = true
			mut state := element.state
			state.values[element.index] = vm.argument(0)
			state.remaining--
			if state.remaining == 0 {
				array := ArrayObject.create_from(mut vm, vm.realm(), state.values, vm.realm().array_prototype_record())!.object
				call(mut vm, state.capability.resolve, js_undefined(), [Value.from_object(array)])!
			}
			return js_undefined()
		}, 1, PropertyName.from_str(''), none).object
		state.remaining++
		then := next.get_with_prototypes(mut vm, PropertyName.from_str('then'), realm_primitive_prototypes())!
		call(mut vm, then, next, [Value.from_object(fulfilled), capability.reject])!
	}
	return capability.promise
}
