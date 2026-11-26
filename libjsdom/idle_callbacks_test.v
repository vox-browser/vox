// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import libjs
import os
import platform
import rand

fn test_idle_callbacks_use_native_window_handles_deadlines_and_ignore_returned_thenables() {
	mut host, mut vm, mut window, errors := frame_fixture()!
	defer { host.close() }
	mut arena := platform.new_arena('native idle callback')
	entry := arena.enter()
	assert frame_eval(mut vm, 'var calls=0,deadline,strictReceiver=false,thenReads=0;var handle=requestIdleCallback(function(value){"use strict";strictReceiver=this===undefined&&arguments.length===1;deadline=value;calls++;return {get then(){thenReads++;throw 1}}},{timeout:1000});calls===0&&requestIdleCallback.length===1&&cancelIdleCallback.length===1')!.as_bool()
	arena.leave(entry)
	for _, record in host.idle_callbacks { assert !arena.contains(record) && !arena.contains(record.callback.as_object()) }
	arena.reset(); arena.release()
	assert host.idle_callbacks.len == 1 && window.has_idle_callbacks()
	handle := u32(vm.global_object().get(mut vm, libjs.PropertyName.from_str('handle'))!.number)
	window.invoke_idle_callback_timeout(handle)
	assert frame_eval(mut vm, 'calls===1&&strictReceiver&&thenReads===0&&deadline instanceof IdleDeadline&&deadline.didTimeout&&deadline.timeRemaining()===0&&Object.prototype.toString.call(deadline)==="[object IdleDeadline]"')!.as_bool()
	assert host.idle_callbacks.len == 0 && !window.has_idle_callbacks() && errors.values.len == 0
	frame_eval(mut vm, 'cancelIdleCallback(0)')!
	assert host.retired_idle_closures.len == 0
}

fn test_idle_callback_required_arguments_dictionary_conversion_and_deadline_brands() {
	mut host, mut vm, mut window, errors := frame_fixture()!
	defer { host.close() }
	assert frame_eval(mut vm, 'var errors=0,reads=0;for(var f of [()=>requestIdleCallback(),()=>requestIdleCallback(1),()=>requestIdleCallback(()=>{},1),()=>requestIdleCallback.call({},()=>{}),()=>requestIdleCallback(1,{get timeout(){reads++;return 1}}),()=>cancelIdleCallback(),()=>new IdleDeadline(),()=>IdleDeadline(),()=>IdleDeadline.prototype.timeRemaining.call({}),()=>Object.getOwnPropertyDescriptor(IdleDeadline.prototype,"didTimeout").get.call({})])try{f()}catch(e){if(e instanceof TypeError)errors++}errors===10&&reads===0')!.as_bool()
	assert frame_eval(mut vm, 'var marker={},same=false;try{requestIdleCallback(()=>{},{get timeout(){throw marker}})}catch(e){same=e===marker}var calls=0,handle=requestIdleCallback(()=>calls++,{get timeout(){reads++;return {valueOf(){reads++;return 1000}}}});cancelIdleCallback({valueOf(){reads++;return handle+4294967296}});same&&reads===3')!.as_bool()
	assert host.idle_callbacks.len == 0 && !window.has_idle_callbacks() && errors.values.len == 0
}

fn test_idle_callback_errors_cancellation_during_delivery_and_shutdown_clear_roots() {
	mut host, mut vm, mut window, errors := frame_fixture()!
	frame_eval(mut vm, 'var calls=0,cancelled;var first=requestIdleCallback(()=>{cancelIdleCallback(cancelled);calls++;requestIdleCallback(()=>calls++)});cancelled=requestIdleCallback(()=>calls+=100);var failed=requestIdleCallback(()=>{throw Error("idle failure")}),infinite=requestIdleCallback(()=>{while(true){}})')!
	for name in ['first','failed','infinite'] {
		handle := u32(vm.global_object().get(mut vm, libjs.PropertyName.from_str(name))!.number)
		window.invoke_idle_callback_timeout(handle)
	}
	assert frame_eval(mut vm, 'calls===1')!.as_bool()
	assert host.idle_callbacks.len == 1 && errors.values.len == 2 && errors.values[0].contains('idle failure') && errors.values[1].contains('instruction budget')
	host.close()
	assert host.idle_callbacks.len == 0 && host.idle_deadlines.len == 0 && host.retired_idle_closures.len == 0 && !window.has_idle_callbacks()
	assert vm.interpreter_stack().depth() == 0
}

fn test_cached_idle_callback_uses_reused_native_code_without_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-idle-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm, mut window, errors := frame_fixture()!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		frame_eval(mut vm, 'var answer=0,handle=requestIdleCallback(d=>{answer=d.didTimeout?42:0},{timeout:1000})')!
		handle := u32(vm.global_object().get(mut vm, libjs.PropertyName.from_str('handle'))!.number)
		window.invoke_idle_callback_timeout(handle)
		assert vm.global_object().get(mut vm, libjs.PropertyName.from_str('answer'))!.number == 42
		activity := vm.diagnose_native_code(false)!; stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		assert errors.values.len == 0
		vm.close_native_code()!; host.close()
	}
}
