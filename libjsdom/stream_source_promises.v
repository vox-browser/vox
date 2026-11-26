// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import libjs
import platform
import webidl

@[heap]
struct StreamPromiseAdoption {
mut:
	host ?&Host
	native ?&webidl.Promise
}

// Traced callable records retain the pending native capability. They do not
// install a process-wide V capture for each author callback return value.
@[heap]
struct StreamAdoptionFunction {
	object &libjs.Object
	realm_ &libjs.Realm
	binding &StreamPromiseAdoption
	reject bool
}

fn (function &StreamAdoptionFunction) realm() ?&libjs.Realm { return function.realm_ }
fn (function &StreamAdoptionFunction) name_for_call_stack() libjs.Utf16String { return libjs.utf16_string('') }

fn (mut function StreamAdoptionFunction) internal_call(mut vm libjs.VM, this_value libjs.Value, arguments []libjs.Value) !libjs.Value {
	caller := vm.running_execution_context()
	mut stack := vm.interpreter_stack(); mark := stack.top()
	mut callee := stack.allocate(0, []libjs.Value{}, u32(arguments.len)) or { return vm.throw_error(.range_error, 'Stream callback stack exhausted') }
	defer { stack.deallocate(mark) }
	for index, argument in arguments { callee.set_argument(u32(index), argument) }
	callee.passed_argument_count = u32(arguments.len); callee.function = libjs.FunctionObject(&function); callee.realm = function.realm_; callee.this_value = this_value
	callee.lexical_environment = caller.lexical_environment; callee.variable_environment = caller.variable_environment; callee.private_environment = caller.private_environment
	vm.push_execution_context_checked(mut callee)!
	defer { vm.pop_execution_context() }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut binding := unsafe { &StreamPromiseAdoption(function.binding) }
	mut host := binding.host or { return libjs.js_undefined() }
	mut native := binding.native or { return libjs.js_undefined() }
	binding.host = none; binding.native = none
	host.stream_adoptions.delete(voidptr(binding))
	if host.closed { return libjs.js_undefined() }
	host.stream_inline_native_job = true
	defer { host.stream_inline_native_job = false }
	if function.reject { native.reject(host.stream_webidl_value(vm.argument(0))) }
	else { native.resolve(webidl.undefined_value()) }
	return libjs.js_undefined()
}

fn (mut host Host) stream_adoption_function(mut vm libjs.VM, binding &StreamPromiseAdoption, reject bool) libjs.Value {
	mut object := libjs.Object.create(host.realm, host.realm.function_prototype)
	object.class_name = 'Function'; object.native_callable = true
	function := &StreamAdoptionFunction{object: object, realm_: host.realm, binding: binding, reject: reject}
	object.callable = libjs.FunctionObject(function)
	object.set_function_length(1)
	object.set_function_name(mut vm, libjs.PropertyName.from_str(''), none)
	return libjs.Value.from_object(object)
}

fn (mut host Host) adopt_stream_callback_result(mut vm libjs.VM, value libjs.Value) !&webidl.Promise {
	context := host.authored_stream_realm().promise_context()
	if !value.is_object() { return webidl.create_resolved_promise_for(context, webidl.undefined_value()) }
	// WebIDL creates a fresh intrinsic capability and resolves it, including
	// the observable Get(value, "then"). PromiseResolve's constructor shortcut
	// would incorrectly skip that getter on an intrinsic Promise.
	capability := libjs.new_promise_capability(mut vm, libjs.Value.from_object(host.realm.promise_constructor_record()))!
	libjs.call(mut vm, capability.resolve, libjs.js_undefined(), [value])!
	mut actual := capability.promise.as_object().promise_record or { return vm.throw_error(.type_error, 'Missing intrinsic Promise state') }
	mut native := webidl.create_promise_for(context)
	if actual.state != .pending {
		if actual.state == .rejected {
			if !actual.is_handled { vm.host_promise_rejection_tracker(mut actual, .handle) }
			native.reject(host.stream_webidl_value(actual.result))
		} else { native.resolve(webidl.undefined_value()) }
		actual.set_is_handled()
		return native
	}
	mut binding := &StreamPromiseAdoption{host: &host, native: native}
	host.stream_adoptions[voidptr(binding)] = binding
	libjs.observe_promise_settlement(mut vm, capability.promise,
		host.stream_adoption_function(mut vm, binding, false), host.stream_adoption_function(mut vm, binding, true))!
	return native
}
