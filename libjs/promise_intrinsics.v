// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Promise.cpp, PromiseConstructor.cpp and PromisePrototype.cpp. Ordinary
// constructor/resolution/reaction paths share the VM's FIFO job queue. Promise
// combinators use separate native entrypoints. Async/await uses the internal
// PerformPromiseThen path without an observable result capability.
@[heap]
pub struct JSPromiseCapability {
pub:
	promise Value
	resolve Value
	reject Value
}

struct PromiseReaction {
	handler ?&JobCallback
	capability &JSPromiseCapability = unsafe { nil }
	rejects bool
}

@[heap]
struct PromiseResolvingState {
mut:
	already_resolved bool
}

@[heap]
struct PromiseCapabilityExecutor {
mut:
	resolve Value
	reject Value
}

fn initialize_promise_intrinsics(mut vm VM, mut realm Realm) {
	mut prototype := Object.create(&realm, realm.object_prototype)
	realm.promise_prototype = prototype
	constructor := NativeFunction.create_constructor(mut vm, &realm, realm.function_prototype,
		fn (mut vm VM) !Value { return vm.throw_error(.type_error, 'Promise constructor requires new') },
		promise_constructor_construct, 1, PropertyName.from_str('Promise')).object
	realm.promise_constructor = constructor
	mut function := constructor
	function.define_direct_property(PropertyName.from_str('prototype'), Value.from_object(prototype), 0)
	prototype.define_direct_property(PropertyName.from_str('constructor'), Value.from_object(constructor), attribute_writable | attribute_configurable)
	prototype.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), Value.from_string(vm.create_string_from_str('Promise')), attribute_configurable)
	function.define_native_accessor(mut vm, &realm, PropertyName.from_symbol(vm.well_known_symbol_species()), fn (mut vm VM) !Value { return vm.this_value() }, unsafe { nil }, attribute_configurable, realm.function_prototype)
	install_intrinsic_method(mut vm, &realm, mut function, 'all', 1, promise_constructor_all)
	install_intrinsic_method(mut vm, &realm, mut function, 'race', 1, promise_constructor_race)
	install_intrinsic_method(mut vm, &realm, mut function, 'allSettled', 1, promise_constructor_all_settled)
	install_intrinsic_method(mut vm, &realm, mut function, 'withResolvers', 0, promise_constructor_with_resolvers)
	install_intrinsic_method(mut vm, &realm, mut function, 'resolve', 1, fn (mut vm VM) !Value {
		return promise_resolve(mut vm, vm.this_value(), vm.argument(0))
	})
	install_intrinsic_method(mut vm, &realm, mut function, 'reject', 1, fn (mut vm VM) !Value {
		capability := new_promise_capability(mut vm, vm.this_value())!
		call(mut vm, capability.reject, js_undefined(), [vm.argument(0)])!
		return capability.promise
	})
	install_intrinsic_method(mut vm, &realm, mut prototype, 'then', 2, promise_prototype_then)
	install_intrinsic_method(mut vm, &realm, mut prototype, 'finally', 1, promise_prototype_finally)
	install_intrinsic_method(mut vm, &realm, mut prototype, 'catch', 1, fn (mut vm VM) !Value {
		receiver := vm.this_value()
		method := receiver.get_with_prototypes(mut vm, PropertyName.from_str('then'), realm_primitive_prototypes())!
		return call(mut vm, method, receiver, [js_undefined(), vm.argument(0)])
	})
}

fn promise_constructor_construct(mut vm VM, new_target &Object) !&Object {
	executor := vm.argument(0)
	if !executor.is_function() { return vm.throw_error(.type_error, 'Promise executor must be callable') }
	prototype := get_prototype_from_constructor(mut vm, new_target, fn (realm &Realm) &Object { return realm.promise_prototype or { panic('Missing Promise prototype') } })!
	mut object := Object.create(vm.realm(), prototype)
	object.class_name = 'Promise'
	mut promise := Promise.create(vm.realm())
	promise.object = object
	promise.owner_vm = &vm
	object.promise_record = promise
	resolve, reject := create_promise_resolving_functions(mut vm, promise)
	call(mut vm, executor, js_undefined(), [resolve, reject]) or {
		if !is_throw_completion(err) { return err }
		call(mut vm, reject, js_undefined(), [thrown_value(err)])!
	}
	return object
}

// NewPromiseCapability also accepts custom constructors whose result is not a
// builtin Promise. This is required by @@species and subclassing.
pub fn new_promise_capability(mut vm VM, constructor Value) !&JSPromiseCapability {
	if !constructor.is_constructor() { return vm.throw_error(.type_error, 'Promise capability requires a constructor') }
	mut state := &PromiseCapabilityExecutor{}
	executor := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [state] (mut vm VM) !Value {
		mut record := unsafe { &PromiseCapabilityExecutor(state) }
		if !record.resolve.is_undefined() || !record.reject.is_undefined() { return vm.throw_error(.type_error, 'Promise capability executor called twice') }
		record.resolve, record.reject = vm.argument(0), vm.argument(1)
		return js_undefined()
	}, 2, PropertyName.from_str(''), none).object
	object := construct(mut vm, constructor, [Value.from_object(executor)], constructor.as_object())!
	if !state.resolve.is_function() || !state.reject.is_function() { return vm.throw_error(.type_error, 'Promise resolving functions must be callable') }
	return &JSPromiseCapability{promise: Value.from_object(object), resolve: state.resolve, reject: state.reject}
}

fn create_promise_resolving_functions(mut vm VM, promise &Promise) (Value, Value) {
	state := &PromiseResolvingState{}
	resolve := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [promise, state] (mut vm VM) !Value {
		mut record := unsafe { &PromiseResolvingState(state) }
		if record.already_resolved { return js_undefined() }
		record.already_resolved = true
		resolve_builtin_promise(mut vm, promise, vm.argument(0))!
		return js_undefined()
	}, 1, PropertyName.from_str(''), none).object
	reject := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [promise, state] (mut vm VM) !Value {
		mut record := unsafe { &PromiseResolvingState(state) }
		if record.already_resolved { return js_undefined() }
		record.already_resolved = true
		mut target := unsafe { &Promise(promise) }
		target.reject(mut vm, vm.argument(0))
		return js_undefined()
	}, 1, PropertyName.from_str(''), none).object
	return Value.from_object(resolve), Value.from_object(reject)
}

fn resolve_builtin_promise(mut vm VM, promise &Promise, value Value) ! {
	mut target := unsafe { &Promise(promise) }
	if object := promise.object {
		if value.is_object() && voidptr(value.as_object()) == voidptr(object) {
			target.reject(mut vm, Value.from_object(create_error(mut vm, vm.realm(), .type_error, utf16_string('Cannot resolve promise with itself'))))
			return
		}
	}
	if !value.is_object() { target.fulfill(value); return }
	then := value.as_object().get(mut vm, PropertyName.from_str('then')) or {
		if !is_throw_completion(err) { return err }
		target.reject(mut vm, thrown_value(err))
		return
	}
	if !then.is_function() { target.fulfill(value); return }
	callback := vm.host_make_job_callback(then.as_function())
	owner := &vm
	job := fn [owner, promise, value, callback] () !Value {
		mut vm := unsafe { &VM(owner) }
		vm.consume_execution_budget()!
		resolve, reject := create_promise_resolving_functions(mut vm, promise)
		mut function := unsafe { &JobCallback(callback) }
		vm.host_call_job_callback(mut function, value, [resolve, reject]) or {
			if !is_throw_completion(err) { return err }
			call(mut vm, reject, js_undefined(), [thrown_value(err)])!
		}
		return js_undefined()
	}
	vm.host_enqueue_promise_job(job, then.as_function().realm())
}

pub fn promise_resolve(mut vm VM, constructor Value, value Value) !Value {
	if !constructor.is_object() { return vm.throw_error(.type_error, 'Promise resolve requires an object constructor') }
	if value.is_object() {
		if value.as_object().promise_record != none {
			actual := value.as_object().get(mut vm, PropertyName.from_str('constructor'))!
			if is_strictly_equal(actual, constructor) { return value }
		}
	}
	capability := new_promise_capability(mut vm, constructor)!
	call(mut vm, capability.resolve, js_undefined(), [value])!
	return capability.promise
}

fn promise_prototype_then(mut vm VM) !Value {
	value := vm.this_value()
	if !value.is_object() { return vm.throw_error(.type_error, 'Promise then requires a Promise receiver') }
	mut promise := value.as_object().promise_record or { return vm.throw_error(.type_error, 'Promise then requires a Promise receiver') }
	constructor := species_constructor(mut vm, value.as_object(), vm.realm().promise_constructor or { panic('Missing Promise constructor') })!
	capability := new_promise_capability(mut vm, Value.from_object(constructor))!
	fulfilled, rejected := vm.argument(0), vm.argument(1)
	perform_promise_then(mut vm, mut promise, fulfilled, rejected, capability)
	return capability.promise
}

// PerformPromiseThen permits an absent result capability for await's internal
// reactions. It never reads user-replaced then or @@species properties.
fn perform_promise_then(mut vm VM, mut promise Promise, fulfilled Value, rejected Value, capability &JSPromiseCapability) {
	on_fulfilled := PromiseReaction{handler: if fulfilled.is_function() { ?&JobCallback(vm.host_make_job_callback(fulfilled.as_function())) } else { none }, capability: capability}
	on_rejected := PromiseReaction{handler: if rejected.is_function() { ?&JobCallback(vm.host_make_job_callback(rejected.as_function())) } else { none }, capability: capability, rejects: true}
	match promise.state {
		.pending { promise.fulfill_reactions << on_fulfilled; promise.reject_reactions << on_rejected }
		.fulfilled { enqueue_promise_reaction(mut vm, on_fulfilled, promise.result) }
		.rejected {
			if !promise.is_handled { vm.host_promise_rejection_tracker(mut promise, .handle) }
			enqueue_promise_reaction(mut vm, on_rejected, promise.result)
		}
	}
	promise.set_is_handled()
}

fn enqueue_promise_reaction(mut vm VM, reaction PromiseReaction, value Value) {
	owner := &vm
	job := fn [owner, reaction, value] () !Value {
		mut vm := unsafe { &VM(owner) }
		vm.consume_execution_budget()!
		mut result := value
		mut rejects := reaction.rejects
		if callback := reaction.handler {
			mut function := unsafe { &JobCallback(callback) }
			if returned := vm.host_call_job_callback(mut function, js_undefined(), [value]) {
				result = returned
				rejects = false
			} else {
				if !is_throw_completion(err) { return err }
				result = thrown_value(err)
				rejects = true
			}
		}
		if reaction.capability != unsafe { nil } {
			call(mut vm, if rejects { reaction.capability.reject } else { reaction.capability.resolve }, js_undefined(), [result])!
		}
		return js_undefined()
	}
	realm := if callback := reaction.handler { callback.callback.realm() } else { none }
	vm.host_enqueue_promise_job(job, realm)
}
