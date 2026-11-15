// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn promise_constructor_all_settled(mut vm VM) !Value {
	constructor := vm.this_value()
	capability := new_promise_capability(mut vm, constructor)!
	resolve := constructor.as_object().get(mut vm, PropertyName.from_str('resolve')) or { return reject_promise_capability(mut vm, capability, err) }
	if !resolve.is_function() { return reject_promise_capability(mut vm, capability, vm.throw_error(.type_error, 'Promise resolve must be callable')) }
	mut iterator := get_iterator_sync_value(mut vm, vm.argument(0)) or { return reject_promise_capability(mut vm, capability, err) }
	return perform_promise_all_settled(mut vm, mut iterator, constructor, capability, resolve) or {
		if !is_throw_completion(err) { return err }
		completion := if iterator.done { completion_from_error(err) } else { iterator_close(mut vm, iterator, completion_from_error(err)) }
		return reject_promise_capability(mut vm, capability, completion.release_error())
	}
}

// The two handlers for an element share AlreadyCalled, so an adversarial then
// cannot populate that index or decrement RemainingElements more than once.
fn create_settled_element(mut vm VM, record &PromiseAllElement, rejects bool) Value {
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [record, rejects] (mut vm VM) !Value {
		mut element := unsafe { &PromiseAllElement(record) }
		if element.already_called { return js_undefined() }
		element.already_called = true
		mut result := Object.create(vm.realm(), vm.realm().object_prototype)
		result.create_data_property_or_throw(mut vm, PropertyName.from_str('status'), Value.from_string(vm.create_string_from_str(if rejects { 'rejected' } else { 'fulfilled' })))!
		result.create_data_property_or_throw(mut vm, PropertyName.from_str(if rejects { 'reason' } else { 'value' }), vm.argument(0))!
		mut state := element.state
		state.values[element.index] = Value.from_object(result)
		state.remaining--
		if state.remaining == 0 {
			array := ArrayObject.create_from(mut vm, vm.realm(), state.values, vm.realm().array_prototype_record())!.object
			call(mut vm, state.capability.resolve, js_undefined(), [Value.from_object(array)])!
		}
		return js_undefined()
	}, 1, PropertyName.from_str(''), none).object
	return Value.from_object(function)
}

fn perform_promise_all_settled(mut vm VM, mut iterator IteratorRecord, constructor Value, capability &JSPromiseCapability, resolve Value) !Value {
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
		if u64(index) >= 9007199254740991 { return vm.throw_error(.type_error, 'Promise.allSettled index exceeds the safe integer range') }
		state.values << js_undefined()
		next := call(mut vm, resolve, constructor, [step.value])!
		record := &PromiseAllElement{state: state, index: index}
		fulfilled := create_settled_element(mut vm, record, false)
		rejected := create_settled_element(mut vm, record, true)
		state.remaining++
		then := next.get_with_prototypes(mut vm, PropertyName.from_str('then'), realm_primitive_prototypes())!
		call(mut vm, then, next, [fulfilled, rejected])!
	}
	return capability.promise
}
