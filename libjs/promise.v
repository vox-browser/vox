module libjs

// Translated from the Promise state machine in LibJS/Runtime/Promise.{h,cpp} and
// the PromiseCapability record. Reaction records, resolving functions, and
// perform_then() belong to the pending builtin-object translation, so only the
// settled-state transitions that the VM observes are implemented.

pub enum PromiseState {
	pending
	fulfilled
	rejected
}

pub enum RejectionOperation {
	reject
	handle
}

@[heap]
pub struct Promise {
pub mut:
	state      PromiseState // [[PromiseState]]
	is_handled bool         // [[PromiseIsHandled]]
	result     Value        // [[PromiseResult]]
}

pub fn Promise.create(realm &Realm) &Promise {
	return &Promise{}
}

pub fn (promise &Promise) is_settled() bool {
	return promise.state == .fulfilled || promise.state == .rejected
}

pub fn (mut promise Promise) set_is_handled() {
	promise.is_handled = true
}

// 27.2.1.4 FulfillPromise ( promise, value ), https://tc39.es/ecma262/#sec-fulfillpromise
pub fn (mut promise Promise) fulfill(value Value) {
	// 1. Assert: The value of promise.[[PromiseState]] is pending.
	if promise.state != .pending {
		panic('fulfill() called on a settled promise')
	}
	// 3. Set promise.[[PromiseResult]] to value.
	promise.result = value
	// 6. Set promise.[[PromiseState]] to fulfilled.
	promise.state = .fulfilled
	// 7. TriggerPromiseReactions is part of the pending reaction translation.
}

// 27.2.1.7 RejectPromise ( promise, reason ), https://tc39.es/ecma262/#sec-rejectpromise
pub fn (mut promise Promise) reject(mut vm VM, reason Value) {
	// 1. Assert: The value of promise.[[PromiseState]] is pending.
	if promise.state != .pending {
		panic('reject() called on a settled promise')
	}
	// 3. Set promise.[[PromiseResult]] to reason.
	promise.result = reason
	// 6. Set promise.[[PromiseState]] to rejected.
	promise.state = .rejected
	// 7. If promise.[[PromiseIsHandled]] is false, perform HostPromiseRejectionTracker(promise, "reject").
	if !promise.is_handled {
		vm.host_promise_rejection_tracker(mut promise, RejectionOperation.reject)
	}
	// 8. TriggerPromiseReactions is part of the pending reaction translation.
}

// 27.2.1.1 PromiseCapability Records, https://tc39.es/ecma262/#sec-promisecapability-records
@[heap]
// Resolve and reject are optional until promise resolving functions are translated.
pub struct PromiseCapability {
pub:
	promise &Promise
	resolve ?FunctionObject
	reject  ?FunctionObject
}

pub fn PromiseCapability.create(promise &Promise, resolve ?FunctionObject, reject ?FunctionObject) &PromiseCapability {
	return &PromiseCapability{
		promise: promise
		resolve: resolve
		reject:  reject
	}
}
