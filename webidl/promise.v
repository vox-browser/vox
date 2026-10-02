// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebIDL/Promise.{h,cpp}. A host may bind Promise reaction jobs
// to the relevant event loop; standalone callers retain the direct job adapter.
module webidl

pub enum PromiseState {
	pending
	fulfilled
	rejected
}

pub type ReactionSteps = fn (Value) !Value

pub type PromiseJobScheduler = fn (fn ())

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
	state                                  PromiseState
	result                                 Value
	is_handled                             bool
	rejection_was_handled_after_settlement bool
mut:
	realm_id  u64
	job_scheduler ?PromiseJobScheduler
	reactions []PromiseReaction
	observers []PromiseObserver
	already_resolved bool
}

// PromiseContext is the standalone boundary for the relevant Realm obtained
// from an environment settings object, JS object, DOM node, or Window.
pub struct PromiseContext {
pub:
	realm_id u64
	job_scheduler ?PromiseJobScheduler
}

pub fn create_promise() &Promise {
	return create_promise_in_realm(0)
}

pub fn create_promise_in_realm(realm_id u64) &Promise {
	return &Promise{
		state: .pending
		result: undefined_value()
		realm_id: realm_id
	}
}

pub fn create_promise_for(context PromiseContext) &Promise {
	return &Promise{
		state: .pending
		result: undefined_value()
		realm_id: context.realm_id
		job_scheduler: context.job_scheduler
	}
}

pub fn create_resolved_promise(value Value) &Promise {
	mut promise := create_promise()
	promise.resolve(value)
	return promise
}

pub fn create_resolved_promise_for(context PromiseContext, value Value) &Promise {
	mut promise := create_promise_for(context)
	promise.resolve(value)
	return promise
}

pub fn create_rejected_promise(reason Value) &Promise {
	mut promise := create_promise()
	promise.reject(reason)
	return promise
}

pub fn create_rejected_promise_for(context PromiseContext, reason Value) &Promise {
	mut promise := create_promise_for(context)
	promise.reject(reason)
	return promise
}

pub fn promise_realm(promise &Promise) u64 {
	return promise.realm_id
}

pub fn resolve_promise(mut promise Promise, value Value) {
	promise.resolve(value)
}

pub fn reject_promise(mut promise Promise, reason Value) {
	promise.reject(reason)
}

pub fn (mut promise Promise) resolve(value Value) {
	if promise.already_resolved { return }
	promise.already_resolved = true
	promise.resolve_value(value)
}

pub fn (mut promise Promise) reject(reason Value) {
	if promise.already_resolved { return }
	promise.already_resolved = true
	promise.settle(.rejected, reason)
}

// WebIDL::create_resolved_promise calls its capability's Resolve function.
// This translates the native-Promise branch of LibJS Promise Resolve Functions
// and NewPromiseResolveThenableJob. Arbitrary JS object getters/thenables still
// belong to the JS object runtime; an actual Promise is retained by identity.
fn (mut promise Promise) resolve_value(value Value) {
	if promise.state != .pending { return }
	if value.kind == .promise {
		mut source := value.promise_value_ or {
			promise.settle(.rejected, string_value('TypeError: Missing native Promise value'))
			return
		}
		if source == &promise {
			promise.settle(.rejected, string_value('TypeError: Cannot resolve promise with itself'))
			return
		}
		// The builtin then callback belongs to the source Promise's realm.
		source.enqueue_job(fn [mut promise, mut source] () {
			source.observe(fn [mut promise] (result Value) !Value {
				promise.resolve_value(result)
				return undefined_value()
			}, fn [mut promise] (reason Value) !Value {
				promise.settle(.rejected, reason)
				return undefined_value()
			})
		})
		return
	}
	promise.settle(.fulfilled, value)
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
		promise.enqueue_job(fn [state, value, reaction] () { run_reaction(state, value, reaction) })
	}
	observers := promise.observers.clone()
	promise.observers.clear()
	for observer in observers {
		promise.enqueue_job(fn [state, value, observer] () {
			if state == .fulfilled { observer.on_fulfilled(value) or {} }
			else { observer.on_rejected(value) or {} }
		})
	}
}

fn (promise &Promise) enqueue_job(job fn ()) {
	if scheduler := promise.job_scheduler { scheduler(job) } else { job() }
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
	promise.mark_as_handled()
	mut child := create_promise_for(PromiseContext{ realm_id: promise.realm_id, job_scheduler: promise.job_scheduler })
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
		state := promise.state
		value := promise.result
		promise.enqueue_job(fn [state, value, reaction] () { run_reaction(state, value, reaction) })
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
	promise.mark_as_handled()
	if promise.state == .pending {
		promise.observers << PromiseObserver{
			on_fulfilled: on_fulfilled
			on_rejected: on_rejected
		}
		return
	}
	state := promise.state
	value := promise.result
	promise.enqueue_job(fn [state, value, on_fulfilled, on_rejected] () {
		if state == .fulfilled { on_fulfilled(value) or {} }
		else { on_rejected(value) or {} }
	})
}

pub fn (mut promise Promise) mark_as_handled() {
	if promise.state == .rejected && !promise.is_handled {
		// This records the host rejection-tracker Handle operation performed by
		// upstream when an already-rejected promise becomes handled.
		promise.rejection_was_handled_after_settlement = true
	}
	promise.is_handled = true
}

pub fn (promise &Promise) is_fulfilled() bool {
	return promise.state == .fulfilled
}

pub fn (promise &Promise) is_rejected() bool {
	return promise.state == .rejected
}

pub type WaitSuccessSteps = fn ([]Value)

pub type WaitFailureSteps = fn (Value)

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

pub type CallbackOperation = fn (Value, []Value) !Value

pub struct CallbackType {
pub:
	callback                  CallbackOperation @[required]
	operation_returns_promise OperationReturnsPromise
	promise_context           ?PromiseContext
}

pub fn call_user_object_operation(callback CallbackType, this_argument ?Value, arguments []Value) !Value {
	this_value := this_argument or { undefined_value() }
	return callback.callback(this_value, arguments) or {
		if callback.operation_returns_promise == .yes {
			return promise_value(create_rejected_promise_for(callback.promise_context or { PromiseContext{} }, string_value(err.msg())))
		}
		return err
	}
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

pub fn create_rejected_promise_from_exception_for(context PromiseContext, exception SimpleException) &Promise {
	mut promise := create_promise_for(context)
	reject_promise_with_exception(mut promise, exception)
	return promise
}

pub fn reject_promise_with_exception(mut promise Promise, exception SimpleException) {
	promise.reject(string_value(exception.message))
}

pub fn create_rejected_promise_from_dom_exception(exception DOMException) &Promise {
	return create_rejected_promise(dom_exception_value(exception))
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
	operation := property.callback_operation or {
		return error('TypeError: callable property has no executable callback')
	}
	return CallbackConversion{
		callback: CallbackType{
			callback: operation
			operation_returns_promise: operation_returns_promise
		}
	}
}
