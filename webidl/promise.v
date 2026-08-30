// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebIDL/Promise.{h,cpp}. The translated event-loop boundary is
// deterministic: settlement reactions run when settle()/flush_microtasks() is
// invoked, preserving order and single-settlement semantics.
module webidl

pub enum PromiseState {
	pending
	fulfilled
	rejected
}

pub type ReactionSteps = fn(Value) !Value

struct PromiseReaction {
	on_fulfilled     ReactionSteps = unsafe { nil }
	on_rejected      ReactionSteps = unsafe { nil }
	has_on_fulfilled bool
	has_on_rejected  bool
	child            &Promise = unsafe { nil }
}

struct PromiseObserver {
	on_fulfilled ReactionSteps @[required]
	on_rejected  ReactionSteps @[required]
}

@[heap]
pub struct Promise {
pub mut:
	state      PromiseState
	result     Value
	is_handled bool
mut:
	reactions []PromiseReaction
	observers []PromiseObserver
}

pub fn create_promise() &Promise {
	return &Promise{
		state: .pending
		result: undefined_value()
	}
}

pub fn create_resolved_promise(value Value) &Promise {
	mut promise := create_promise()
	promise.resolve(value)
	return promise
}

pub fn create_rejected_promise(reason Value) &Promise {
	mut promise := create_promise()
	promise.reject(reason)
	return promise
}

pub fn (mut promise Promise) resolve(value Value) {
	promise.settle(.fulfilled, value)
}

pub fn (mut promise Promise) reject(reason Value) {
	promise.settle(.rejected, reason)
}

fn (mut promise Promise) settle(state PromiseState, value Value) {
	if promise.state != .pending {
		return
	}
	promise.state = state
	promise.result = value
	reactions := promise.reactions.clone()
	promise.reactions.clear()
	for reaction in reactions {
		run_reaction(state, value, reaction)
	}
	observers := promise.observers.clone()
	promise.observers.clear()
	for observer in observers {
		if state == .fulfilled {
			observer.on_fulfilled(value) or {}
		} else {
			observer.on_rejected(value) or {}
		}
	}
}

fn run_reaction(state PromiseState, value Value, reaction PromiseReaction) {
	mut child := reaction.child
	if (state == .fulfilled && reaction.has_on_fulfilled) || (state == .rejected && reaction.has_on_rejected) {
		steps := if state == .fulfilled { reaction.on_fulfilled } else { reaction.on_rejected }
		result := steps(value) or {
			child.reject(string_value(err.msg()))
			return
		}
		child.resolve(result)
		return
	}
	if state == .fulfilled {
		child.resolve(value)
	} else {
		child.reject(value)
	}
}

fn absent_reaction(value Value) !Value {
	return value
}

fn (mut promise Promise) react(on_fulfilled ReactionSteps, has_on_fulfilled bool, on_rejected ReactionSteps, has_on_rejected bool) &Promise {
	mut child := create_promise()
	reaction := PromiseReaction{
		on_fulfilled: on_fulfilled
		on_rejected: on_rejected
		has_on_fulfilled: has_on_fulfilled
		has_on_rejected: has_on_rejected
		child: child
	}
	if promise.state == .pending {
		promise.reactions << reaction
	} else {
		run_reaction(promise.state, promise.result, reaction)
	}
	return child
}

pub fn (mut promise Promise) upon_fulfillment(steps ReactionSteps) &Promise {
	return promise.react(steps, true, absent_reaction, false)
}

pub fn (mut promise Promise) upon_rejection(steps ReactionSteps) &Promise {
	return promise.react(absent_reaction, false, steps, true)
}

fn (mut promise Promise) observe(on_fulfilled ReactionSteps, on_rejected ReactionSteps) {
	if promise.state == .pending {
		promise.observers << PromiseObserver{
			on_fulfilled: on_fulfilled
			on_rejected: on_rejected
		}
		return
	}
	if promise.state == .fulfilled {
		on_fulfilled(promise.result) or {}
	} else {
		on_rejected(promise.result) or {}
	}
}

pub fn (mut promise Promise) mark_as_handled() {
	promise.is_handled = true
}

pub fn (promise &Promise) is_fulfilled() bool {
	return promise.state == .fulfilled
}

pub fn (promise &Promise) is_rejected() bool {
	return promise.state == .rejected
}

pub type WaitSuccessSteps = fn([]Value)

pub type WaitFailureSteps = fn(Value)

@[heap]
struct WaitForAllState {
mut:
	results       []Value
	fulfilled     int
	finished      bool
	success_steps WaitSuccessSteps @[required]
	failure_steps WaitFailureSteps @[required]
}

fn (mut state WaitForAllState) fulfill(index int, value Value) !Value {
	if state.finished {
		return value
	}
	state.results[index] = value
	state.fulfilled++
	if state.fulfilled == state.results.len {
		state.finished = true
		state.success_steps(state.results.clone())
	}
	return value
}

fn (mut state WaitForAllState) reject(reason Value) !Value {
	if !state.finished {
		state.finished = true
		state.failure_steps(reason)
	}
	return reason
}

// wait_for_all installs reactions on pending inputs, retains list order and
// invokes exactly one terminal callback, matching WebIDL::wait_for_all.
pub fn wait_for_all(promises []&Promise, success_steps WaitSuccessSteps, failure_steps WaitFailureSteps) {
	if promises.len == 0 {
		success_steps([]Value{})
		return
	}
	mut state := &WaitForAllState{
		results: []Value{len: promises.len, init: undefined_value()}
		success_steps: success_steps
		failure_steps: failure_steps
	}
	for index, promise in promises {
		mut observed := unsafe { &Promise(promise) }
		observed.observe(fn [mut state, index] (value Value) !Value {
			return state.fulfill(index, value)
		}, fn [mut state] (reason Value) !Value {
			return state.reject(reason)
		})
	}
}

// Translation of get_promise_for_wait_for_all: the returned promise adopts
// the ordered result sequence or the first rejection.
pub fn get_promise_for_wait_for_all(promises []&Promise) &Promise {
	mut result := create_promise()
	wait_for_all(promises, fn [mut result] (values []Value) {
		result.resolve(sequence_value(values))
	}, fn [mut result] (reason Value) {
		result.reject(reason)
	})
	return result
}

pub enum OperationReturnsPromise {
	no
	yes
}

pub type CallbackOperation = fn(Value, []Value) !Value

pub struct CallbackType {
pub:
	callback                  CallbackOperation @[required]
	operation_returns_promise OperationReturnsPromise
}

pub fn call_user_object_operation(callback CallbackType, this_argument ?Value, arguments []Value) !Value {
	this_value := this_argument or { undefined_value() }
	return callback.callback(this_value, arguments)
}

pub fn invoke_callback(callback CallbackType, this_argument ?Value, arguments []Value) !Value {
	return call_user_object_operation(callback, this_argument, arguments)
}

pub fn react_to_promise(mut promise Promise, on_fulfilled ReactionSteps, on_rejected ReactionSteps) &Promise {
	return promise.react(on_fulfilled, true, on_rejected, true)
}

pub fn mark_promise_as_handled(mut promise Promise) {
	promise.mark_as_handled()
}

pub fn is_promise_fulfilled(promise &Promise) bool {
	return promise.is_fulfilled()
}

pub fn create_rejected_promise_from_exception(exception SimpleException) &Promise {
	return create_rejected_promise(string_value(exception.message))
}

fn property_callback_stub(_ Value, _ []Value) !Value {
	return undefined_value()
}

pub struct CallbackConversion {
pub:
	callback ?CallbackType
}

pub fn property_to_callback(value Value, property_key string, operation_returns_promise OperationReturnsPromise) !CallbackConversion {
	if value.kind != .object {
		return error('TypeError: callback owner is not an object')
	}
	property := value.object_value[property_key] or { return CallbackConversion{} }
	if property.kind == .undefined {
		return CallbackConversion{}
	}
	if property.kind != .callback {
		return error('TypeError: property is not a function')
	}
	// Value marks callable identity, while executable closures are supplied as
	// CallbackType by generated bindings. The stub is therefore only the raw
	// property-conversion boundary.
	return CallbackConversion{
		callback: CallbackType{
			callback:                  property_callback_stub
			operation_returns_promise: operation_returns_promise
		}
	}
}
