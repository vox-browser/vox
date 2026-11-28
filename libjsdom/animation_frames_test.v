// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import os
import platform
import rand

@[heap]
struct FrameErrors {
mut:
	values []string
}

fn frame_fixture() !(&Host, &libjs.VM, &html.WindowModel, &FrameErrors) {
	address := dom.URL{value: 'https://libjs-frames.test/'}
	mut document := html.parse_navigation_document('<body></body>', address, address.origin(), none)!
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	errors := &FrameErrors{}
	mut host := Host.create(vm, vm.realm(), document, Hooks{exception: fn [errors] (message string) {
		mut state := unsafe { &FrameErrors(errors) }; state.values << message
	}})!
	window := host.frame_window(mut vm)!
	return host, vm, window, errors
}

fn frame_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'native-animation-frame.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 100000}) or { return error(exception_message(err)) }
}

fn test_animation_frame_callbacks_use_actual_window_driver_time_and_callback_receivers() {
	mut host, mut vm, mut window, errors := frame_fixture()!
	defer { host.close() }
	assert frame_eval(mut vm, 'var seen=[],receiver=false,strictReceiver=false,thenReads=0;var first=requestAnimationFrame(function(now){receiver=this===window;seen.push(now);return {get then(){thenReads++;throw 42}}});requestAnimationFrame(function(now){"use strict";strictReceiver=this===undefined;seen.push(now)});typeof first==="number"&&first>0&&seen.length===0&&requestAnimationFrame.length===1&&cancelAnimationFrame.length===1')!.as_bool()
	assert window.has_animation_frame_callbacks() && host.animation_frames.len == 2
	mut scratch := platform.new_arena('native-frame-delivery')
	entry := scratch.enter()
	window.run_animation_frame_callbacks(12.5)
	scratch.leave(entry)
	assert !scratch.contains(host.retired_frame_closures.data)
	scratch.reset()
	scratch.release()
	assert frame_eval(mut vm, 'seen.length===2&&seen[0]===12.5&&seen[1]===12.5&&receiver&&strictReceiver&&thenReads===0')!.as_bool()
	assert !window.has_animation_frame_callbacks() && host.animation_frames.len == 0 && host.retired_frame_closures.len == 1
	assert errors.values.len == 0
}

fn test_animation_frame_cancellation_during_batch_and_next_frame_registration() {
	mut host, mut vm, mut window, errors := frame_fixture()!
	defer { host.close() }
	frame_eval(mut vm, 'var order="",second,first;first=requestAnimationFrame(function(){order+="a";cancelAnimationFrame(first);cancelAnimationFrame(second);requestAnimationFrame(function(){order+="c"})});second=requestAnimationFrame(function(){order+="b"})')!
	window.run_animation_frame_callbacks(10)
	assert frame_eval(mut vm, 'order==="a"')!.as_bool()
	assert host.animation_frames.len == 1 && window.has_animation_frame_callbacks()
	window.run_animation_frame_callbacks(20)
	assert frame_eval(mut vm, 'order==="ac"')!.as_bool()
	assert host.animation_frames.len == 0 && host.retired_frame_closures.len == 1 && errors.values.len == 0
	frame_eval(mut vm, 'cancelAnimationFrame(0)')!
	assert host.retired_frame_closures.len == 0
}

fn test_animation_frame_webidl_required_arguments_brand_and_unsigned_handle_conversion() {
	mut host, mut vm, mut window, errors := frame_fixture()!
	defer { host.close() }
	assert frame_eval(mut vm, 'var failures=0,coerced=0;for(var run of [()=>requestAnimationFrame(),()=>requestAnimationFrame({}),()=>requestAnimationFrame.call({},function(){}),()=>cancelAnimationFrame(),()=>cancelAnimationFrame(Symbol()),()=>cancelAnimationFrame(1n),()=>cancelAnimationFrame.call({},{valueOf(){coerced++;return 0}})])try{run()}catch(e){if(e instanceof TypeError)failures++}failures===7&&coerced===0')!.as_bool()
	assert frame_eval(mut vm, 'var called=0,handle=requestAnimationFrame(()=>called++);cancelAnimationFrame({valueOf(){coerced++;return handle+4294967296}});var marker={},same=false;try{cancelAnimationFrame({valueOf(){throw marker}})}catch(e){same=e===marker}same&&coerced===1')!.as_bool()
	window.run_animation_frame_callbacks(1)
	assert frame_eval(mut vm, 'called===0')!.as_bool()
	assert host.animation_frames.len == 0 && errors.values.len == 0
}

fn test_animation_frame_errors_and_budget_exhaustion_do_not_stop_later_callbacks_and_close_cancels_pending() {
	mut host, mut vm, mut window, errors := frame_fixture()!
	defer { host.close() }
	frame_eval(mut vm, 'var called=0;requestAnimationFrame(function(){throw new Error("frame failure")});requestAnimationFrame(function(){while(true){}});requestAnimationFrame(function(){called++})')!
	window.run_animation_frame_callbacks(10)
	assert frame_eval(mut vm, 'called===1')!.as_bool()
	assert errors.values.len == 2 && errors.values[0].contains('frame failure') && errors.values[1].contains('instruction budget')
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
	frame_eval(mut vm, 'requestAnimationFrame(function(){called++})')!
	host.close()
	assert host.animation_frames.len == 0 && host.retired_frame_closures.len == 0 && !window.has_animation_frame_callbacks()
	window.run_animation_frame_callbacks(20)
	assert vm.global_object().get(mut vm, libjs.PropertyName.from_str('called'))!.number == 1
}

fn test_cached_animation_frame_callback_runs_in_fresh_vm_without_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-native-frames-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm, mut window, errors := frame_fixture()!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		frame_eval(mut vm, 'var seen=0;requestAnimationFrame(function(now){seen=now})')!
		window.run_animation_frame_callbacks(42)
		assert vm.global_object().get(mut vm, libjs.PropertyName.from_str('seen'))!.number == 42
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		assert errors.values.len == 0
		vm.close_native_code()!
		host.close()
	}
}
