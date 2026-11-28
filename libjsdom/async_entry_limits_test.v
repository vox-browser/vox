// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs

@[heap]
struct AsyncLimitErrors {
mut:
	messages []string
}

fn async_limit_fixture(limit u64, allowed bool) !(&Host, &libjs.VM, &AsyncLimitErrors) {
	address := dom.URL{ value: 'https://async-limits.test/' }
	document := html.parse_navigation_document('<body></body>', address, address.origin(), none)!
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	errors := &AsyncLimitErrors{}
	host := Host.create(vm, vm.realm(), document, Hooks{
		execution_limits: libjs.ExecutionLimits{ max_instructions: limit }
		can_run_callback: fn [allowed] () bool { return allowed }
		exception:        fn [errors] (text string) {
			mut state := unsafe { &AsyncLimitErrors(errors) }
			state.messages << text
		}
	})!
	return host, vm, errors
}

fn limited_async_callback(mut vm libjs.VM) !libjs.Value {
	for _ in 0 .. 10 { vm.consume_execution_budget()! }
	return libjs.Value.from_i32(42)
}

fn test_stream_and_fetch_native_entries_obey_the_owning_host_instruction_limit() {
	for limit in [u64(3), u64(100)] {
		mut host, _, errors := async_limit_fixture(limit, true)!
		if value := host.stream_entry(limited_async_callback) {
			assert limit == 100 && value.number == 42
		} else {
			assert limit == 3 && exception_message(err).contains('instruction budget')
		}
		host.invoke_fetch_callback(limited_async_callback)
		assert errors.messages.len == if limit == 3 { 1 } else { 0 }
		if limit == 3 {
			assert errors.messages[0].contains('instruction budget')
		}
		host.close()
	}
}

fn test_blocked_native_fetch_entry_does_not_call_author_code() {
	mut host, mut vm, errors := async_limit_fixture(100, false)!
	defer { host.close() }
	host.invoke_fetch_callback(fn (mut vm libjs.VM) !libjs.Value {
		mut global := vm.global_object()
		global.define_direct_property(libjs.PropertyName.from_str('called'), libjs.Value.from_bool(true), libjs.attribute_configurable)
		return libjs.js_undefined()
	})
	assert vm.global_object().get(mut vm, libjs.PropertyName.from_str('called'))!.is_undefined()
	assert errors.messages.len == 0
}
