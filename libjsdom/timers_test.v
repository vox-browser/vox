// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import highresolutiontime
import html
import libjs
import os
import platform
import rand
import time

fn timers_fixture() !(&Host, &libjs.VM, &html.WindowModel) {
	address := dom.URL{value: 'https://libjs-timers.test/document.html'}
	mut document := html.parse_navigation_document('<body></body>', address, address.origin(), none)!
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	return host, vm, host.frame_window(mut vm)!
}

fn timers_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'native-timers.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 100000}) or { return error(exception_message(err)) }
}

fn test_native_timers_preserve_callback_this_arguments_tasks_and_ignore_thenable_returns() {
	mut host, mut vm, window := timers_fixture()!
	defer { host.close() }
	timers_eval(mut vm, 'var argument={},calls=0,thenReads=0,identity=false;var id=setTimeout(function(first,second){"use strict";calls++;identity=this===window&&first===argument&&second===undefined;return {get then(){thenReads++;throw 1}}},5,argument,undefined)')!
	assert host.timers.len == 1
	mut scope := window.window_or_worker_global_scope()
	scope.run_all_timers()
	assert timers_eval(mut vm, 'calls===1&&identity&&thenReads===0&&id>0')!.as_bool()
	assert scope.active_timer_count() == 0 && host.timers.len == 0
	assert scope.reported_errors().len == 0
}

fn test_timer_clear_methods_share_ids_cancel_queued_tasks_and_release_roots() {
	mut host, mut vm, window := timers_fixture()!
	defer { host.close() }
	timers_eval(mut vm, 'var calls=0;var id=setTimeout(()=>calls++,1,{});clearInterval(id);clearTimeout();clearInterval(undefined)')!
	assert host.timers.len == 0
	mut scope := window.window_or_worker_global_scope()
	scope.run_all_timers()
	assert timers_eval(mut vm, 'calls===0')!.as_bool()
	settings := unsafe { &html.EnvironmentSettingsObject(host.document.relevant_settings_object()) }
	mut loop := settings.responsible_event_loop()
	pause := loop.pause()
	timers_eval(mut vm, 'id=setTimeout(()=>calls++,1,{})')!
	if platform.native_timer_scheduling_available() {
		deadline := time.sys_mono_now() + i64(2000000000)
		for loop.task_queue().is_empty() && time.sys_mono_now() < deadline { platform.pump_native_events(0.01) }
		assert !loop.task_queue().is_empty()
	}
	mut record := host.timers[i32(vm.global_object().get(mut vm, libjs.PropertyName.from_str('id'))!.number)] or { panic('Missing native timer') }
	assert record.conversions.len == 1 && record.callback.is_function()
	timers_eval(mut vm, 'clearTimeout(id)')!
	assert record.callback.is_undefined() && record.conversions.len == 0
	loop.unpause(pause)
	scope.run_all_timers()
	assert timers_eval(mut vm, 'calls===0')!.as_bool()
}

fn test_intervals_reuse_native_id_and_reentrant_cancellation_retires_running_closures() {
	mut host, mut vm, window := timers_fixture()!
	defer { host.close() }
	timers_eval(mut vm, 'var calls=0,nested=0;var id=setInterval(function(){calls++;if(calls===2){clearTimeout(id);setTimeout(()=>nested++,0)}},5)')!
	mut scope := window.window_or_worker_global_scope()
	now := highresolutiontime.unsafe_shared_current_time() + 1000
	scope.process_timers(now)
	assert timers_eval(mut vm, 'calls===1')!.as_bool()
	assert host.timers.len == 1
	scope.process_timers(now + 10)
	scope.run_all_timers()
	assert timers_eval(mut vm, 'calls===2&&nested===1')!.as_bool()
	assert scope.active_timer_count() == 0 && host.timers.len == 0
	timers_eval(mut vm, 'clearTimeout()')!
	assert host.retired_timer_closures.len == 0 && host.timer_callback_depth == 0
}

fn test_timer_webidl_conversion_order_metadata_branding_and_string_classic_scripts() {
	mut host, mut vm, window := timers_fixture()!
	defer { host.close() }
	assert timers_eval(mut vm, 'var order="",sourceDone=0;var id=setTimeout({[Symbol.toPrimitive](hint){order+=hint;return "sourceDone++"}},{valueOf(){order+=",number";return 4294967301.75}});order==="string,number"&&sourceDone===0&&setTimeout.length===1&&setInterval.length===1&&clearTimeout.length===0&&clearInterval.length===0')!.as_bool()
	mut scope := window.window_or_worker_global_scope()
	scope.run_all_timers()
	assert timers_eval(mut vm, 'sourceDone===1')!.as_bool()
	assert timers_eval(mut vm, 'var count=0,coerced=0,marker={},same=false;for(var run of [()=>setTimeout(),()=>setInterval(),()=>setTimeout(Symbol()),()=>setTimeout(()=>0,1n),()=>setTimeout(()=>0,Symbol()),()=>clearTimeout(1n),()=>clearInterval(Symbol()),()=>setTimeout.call({},{toString(){coerced++;return ""}}),()=>clearTimeout.call({})])try{run()}catch(e){if(e instanceof TypeError)count++}try{setTimeout(()=>0,{valueOf(){throw marker}})}catch(e){same=e===marker}var d=Object.getOwnPropertyDescriptor(window,"setTimeout");count===9&&coerced===0&&same&&d.writable&&d.enumerable&&d.configurable')!.as_bool()
}

fn test_timers_report_original_reasons_and_respect_native_string_compilation_csp() {
	mut host, mut vm, window := timers_fixture()!
	defer { host.close() }
	timers_eval(mut vm, 'var marker={};setTimeout(()=>{throw marker},0);setTimeout("throw marker",0)')!
	mut scope := window.window_or_worker_global_scope()
	scope.run_all_timers()
	assert scope.reported_errors().len == 2
	marker := vm.global_object().get(mut vm, libjs.PropertyName.from_str('marker'))!
	for reason in scope.reported_errors() {
		actual := host.abort_reason_value(mut vm, reason.as_webidl_value()!)!
		assert libjs.is_strictly_equal(actual, marker)
	}
	mut settings := unsafe { &html.EnvironmentSettingsObject(host.document.relevant_settings_object()) }
	settings.set_policy_container(&html.PolicyContainer{csp_list: [html.parse_response_csp_policy("script-src 'self'", .enforce, host.document.origin())]})
	assert timers_eval(mut vm, 'var blocked=setTimeout("throw 1",0),blockedInterval=setInterval("throw 1",0),calls=0;setTimeout(()=>calls++,0);blocked===0&&blockedInterval===0')!.as_bool()
	scope.run_all_timers()
	assert timers_eval(mut vm, 'calls===1')!.as_bool()
	assert scope.reported_errors().len == 2 && host.timers.len == 0
}

fn test_timer_callbacks_and_string_scripts_share_bounded_entry_and_recover_after_exhaustion() {
	mut host, mut vm, window := timers_fixture()!
	defer { host.close() }
	timers_eval(mut vm, 'setTimeout(()=>{for(;;){}},0);setTimeout("for(;;){}",0)')!
	mut scope := window.window_or_worker_global_scope()
	scope.run_all_timers()
	assert scope.reported_errors().len == 2 && host.timers.len == 0
	for reason in scope.reported_errors() {
		actual := host.abort_reason_value(mut vm, reason.as_webidl_value()!)!
		assert actual.as_object().error_kind() or { panic('Missing timer budget error') } == .internal_error
		assert (actual.as_object().error_message() or { '' }).contains('budget')
	}
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
	timers_eval(mut vm, 'var recovered=false;setTimeout(()=>recovered=true,0)')!
	scope.run_all_timers()
	assert timers_eval(mut vm, 'recovered')!.as_bool()
}

fn test_native_clock_delivers_timer_callbacks_without_manual_clock_adapters() {
	if !platform.native_timer_scheduling_available() { return }
	mut host, mut vm, window := timers_fixture()!
	defer { host.close() }
	timers_eval(mut vm, 'var actualClock=false;setTimeout(()=>actualClock=true,5)')!
	deadline := time.sys_mono_now() + i64(2000000000)
	for time.sys_mono_now() < deadline {
		platform.pump_native_events(0.01)
		if vm.global_object().get(mut vm, libjs.PropertyName.from_str('actualClock'))!.as_bool() { break }
	}
	assert vm.global_object().get(mut vm, libjs.PropertyName.from_str('actualClock'))!.as_bool()
	assert window.window_or_worker_global_scope().active_timer_count() == 0 && host.timers.len == 0
}

fn test_cached_native_timer_callbacks_run_without_compiler_and_close_cancels_pending_work() {
	directory := os.join_path(os.getenv_opt('TMPDIR') or { os.temp_dir() }, 'vox-native-timers-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm, window := timers_fixture()!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		timers_eval(mut vm, 'var calls=0;setTimeout(function(){calls=42},0)')!
		mut scope := window.window_or_worker_global_scope()
		scope.run_all_timers()
		assert vm.global_object().get(mut vm, libjs.PropertyName.from_str('calls'))!.number == 42
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
		timers_eval(mut vm, 'setTimeout(()=>calls++,0,{});setInterval(()=>calls++,1)')!
		host.close()
		scope.run_all_timers()
		assert vm.global_object().get(mut vm, libjs.PropertyName.from_str('calls'))!.number == 42
		assert host.timers.len == 0 && host.retired_timer_closures.len == 0 && scope.active_timer_count() == 0
	}
}
