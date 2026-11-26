// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import libjs
import platform
import streams
import webidl

fn (host &Host) stream_webidl_value(value libjs.Value) webidl.Value {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	return webidl.runtime_value(webidl.RuntimeValue{
		context: voidptr(host)
		value: &libjs.Value{...value}
		is_undefined: value.is_undefined()
		number_primitive: if value.is_number() { ?f64(value.number) } else { none }
		// Native queueing never converts a chunk/reason to a string. Actual
		// author conversions run after unboxing in this owning VM.
		string_conversion: fn () !string { return error('Stream value conversion requires its owning VM') }
	})
}

fn (mut host Host) stream_error_value(mut vm libjs.VM, reason webidl.Value) !libjs.Value {
	if exception := reason.simple_exception_ {
		key := voidptr(exception)
		if cached := host.stream_errors[key] { return cached }
		kind := match exception.type_ {
			.eval_error { libjs.ErrorKind.eval_error }
			.range_error { libjs.ErrorKind.range_error }
			.reference_error { libjs.ErrorKind.reference_error }
			.type_error { libjs.ErrorKind.type_error }
			.uri_error { libjs.ErrorKind.uri_error }
		}
		value := libjs.Value.from_object(libjs.create_error(mut vm, host.realm, kind, libjs.utf16_string(exception.message)))
		host.stream_errors[key] = value
		return value
	}
	return host.abort_reason_value(mut vm, reason)
}

fn (mut host Host) stream_value_to_js(mut vm libjs.VM, value streams.Value) !libjs.Value {
	return match value.kind {
		.undefined { libjs.js_undefined() }
		.null_ { libjs.js_null() }
		.boolean { libjs.Value.from_bool(value.boolean) }
		.number { libjs.Value.from_f64(value.number) }
		.string_ { libjs.Value.from_string(vm.create_string_from_str(value.text)) }
		.bytes {
			charge_buffer_source_work(mut vm, u64(value.bytes_.len))!
			host.uint8_array_from_bytes(value.bytes_)
		}
		.array {
			mut items := []libjs.Value{cap: value.items.len}
			for item in value.items { vm.consume_execution_budget()!; items << host.stream_value_to_js(mut vm, item)! }
			libjs.Value.from_object(libjs.ArrayObject.create_from(mut vm, host.realm, items, host.realm.array_prototype_record())!.object)
		}
		.runtime_value {
			actual := value.runtime_value_ or { return vm.throw_error(.type_error, 'Missing native stream value') }
			host.abort_reason_value(mut vm, actual)!
		}
	}
}

// Native controllers may settle several reads and then close in one task.
// Update capabilities without checkpointing JS reactions in the middle of it.
fn (mut host Host) stream_entry(callback libjs.NativeFunctionPointer) !libjs.Value {
	defer { platform.release_closure(voidptr(callback)) }
	host.require_open(mut host.vm)!
	if can_run := host.hooks.can_run_callback { if !can_run() { return libjs.js_undefined() } }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if before := host.hooks.before_callback { before() }
	defer { if after := host.hooks.after_callback { after() } }
	mut vm := host.vm
	function := libjs.NativeFunction.create(mut vm, host.realm, host.realm.function_prototype, callback, 0, libjs.PropertyName.from_str('streamCallback'), none).object
	job := fn [mut vm, function] () !libjs.Value { return libjs.call(mut vm, libjs.Value.from_object(function), libjs.js_undefined(), []) }
	defer { platform.release_closure(voidptr(job)) }
	defer { host.changed() }
	return vm.run_promise_job_with_limits(job, host.hooks.execution_limits)
}
