// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import html
import libjs
import platform

fn drain_native_microtasks() {
	mut loop := html.main_thread_event_loop()
	for { task := loop.dequeue_microtask() or { break }; task.execute() }
}

fn test_queue_microtask_is_deferred_and_retains_callbacks_across_temporary_storage() {
	mut host, mut vm, _, errors := frame_fixture()!
	defer { host.close() }
	mut arena := platform.new_arena('queued LibJS microtask')
	entry := arena.enter()
	assert frame_eval(mut vm, 'var calls=0,strictReceiver=false,thenReads=0;queueMicrotask(function(){"use strict";strictReceiver=this===undefined&&arguments.length===0;calls++;return {get then(){thenReads++;throw 1}}});calls===0')!.as_bool()
	arena.leave(entry)
	for _, record in host.microtasks { assert !arena.contains(record) && !arena.contains(record.callback.as_object()) }
	arena.reset(); arena.release()
	drain_native_microtasks()
	assert frame_eval(mut vm, 'calls===1&&strictReceiver&&thenReads===0')!.as_bool()
	assert host.microtasks.len == 0 && errors.values.len == 0
}

fn test_queue_microtask_validates_callback_and_receiver_and_reports_errors_without_stopping_queue() {
	mut host, mut vm, _, errors := frame_fixture()!
	defer { host.close() }
	assert frame_eval(mut vm, 'var errors=0;for(var f of [()=>queueMicrotask(),()=>queueMicrotask(null),()=>queueMicrotask({handleEvent(){}}),()=>queueMicrotask.call({},()=>{}),()=>new queueMicrotask(()=>{})])try{f()}catch(e){if(e instanceof TypeError)errors++}errors===5&&queueMicrotask.length===1&&!Object.hasOwn(queueMicrotask,"prototype")')!.as_bool()
	frame_eval(mut vm, 'var calls=0;queueMicrotask(()=>{throw Error("microtask failure")});queueMicrotask(()=>{while(true){}});queueMicrotask(()=>calls++)')!
	drain_native_microtasks()
	assert frame_eval(mut vm, 'calls===1')!.as_bool()
	assert errors.values.len == 2 && errors.values[0].contains('microtask failure') && errors.values[1].contains('instruction budget')
	assert host.microtasks.len == 0 && vm.interpreter_stack().depth() == 0
}

fn test_closing_document_host_discards_owned_microtasks_before_releasing_native_callbacks() {
	mut host, mut vm, _, errors := frame_fixture()!
	frame_eval(mut vm, 'var calls=0;queueMicrotask(()=>calls++);queueMicrotask(()=>calls++)')!
	assert host.microtasks.len == 2
	host.close()
	assert host.microtasks.len == 0
	drain_native_microtasks()
	assert vm.global_object().get(mut vm, libjs.PropertyName.from_str('calls'))!.number == 0
	assert errors.values.len == 0
}
