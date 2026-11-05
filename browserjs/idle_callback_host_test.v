module browserjs

import dom
import html
import highresolutiontime
import page
import time

fn idle_host_document() (&dom.Document, &page.Page) {
	mut document := html.parse_navigation_document('<!doctype html><body></body>', dom.URL{value: 'https://idle-host.test/'},
		dom.URL{value: 'https://idle-host.test/'}.origin(), none) or { panic(err) }
	mut page_ := page.Page.create(1) or { panic(err) }
	document.set_page(unsafe { &dom.Page(page_) })
	page_.set_local_root_navigable(document.navigable() or { panic('missing navigable') }) or {
		panic(err)
	}
	document.load_timing_info.navigation_start_time = highresolutiontime.unsafe_shared_current_time()
	document.update_the_visibility_state(.visible)
	return document, page_
}

// Run the window event loop until it has no runnable task; an idle loop with
// pending idle callbacks starts an idle period and queues their invocation.
fn idle_host_spin(host &IdleCallbackHost) {
	mut event_loop := unsafe { &html.EventLoop(host.settings.responsible_event_loop()) }
	for _ in 0 .. 4 {
		event_loop.process()
		for event_loop.task_queue().has_runnable_tasks() {
			event_loop.process()
		}
	}
}

fn test_native_idle_callbacks_receive_a_deadline_and_can_be_cancelled() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	mut document, _ := idle_host_document()
	defer {
		runtime.close()
		document.finalize()
	}
	mut host := IdleCallbackHost.create(document, none)!
	host.install(mut runtime)!
	before_roots := runtime.protected_values_.len
	runtime.evaluate_host(r'globalThis.idleCalls=[];globalThis.idleCancelled=0;
 globalThis.firstIdle=requestIdleCallback(function(deadline){"use strict";idleCalls.push([this===undefined,deadline instanceof IdleDeadline,deadline.didTimeout,typeof deadline.timeRemaining(),deadline.timeRemaining()>=0,Object.prototype.toString.call(deadline)])});
 globalThis.cancelledIdle=requestIdleCallback(function(){idleCancelled++},{timeout:0});cancelIdleCallback(cancelledIdle);')!
	assert runtime.evaluate_host('firstIdle>0&&cancelledIdle===firstIdle+1&&idleCalls.length===0')! == 'true'
	assert runtime.protected_values_.len == before_roots + 1
	idle_host_spin(host)
	assert runtime.evaluate_host('JSON.stringify(idleCalls)')! == '[[true,true,false,"number",true,"[object IdleDeadline]"]]'
	assert runtime.evaluate_host('idleCancelled')! == '0'
	assert runtime.protected_values_.len == before_roots
	assert !host.window.has_idle_callbacks()
	// Argument conversion and receiver checks precede native scheduling.
	assert runtime.evaluate_host(r'let errors=0;for(const call of [()=>requestIdleCallback(),()=>requestIdleCallback(1),()=>requestIdleCallback(()=>{},1),()=>cancelIdleCallback(),()=>requestIdleCallback.call({},()=>{})]){try{call()}catch(error){if(error instanceof TypeError)errors++}}errors')! == '5'
	assert runtime.evaluate_host('try{new IdleDeadline();false}catch(error){error instanceof TypeError}')! == 'true'
}

fn test_native_idle_callback_timeout_reports_did_timeout() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	mut document, _ := idle_host_document()
	defer {
		runtime.close()
		document.finalize()
	}
	mut host := IdleCallbackHost.create(document, none)!
	host.install(mut runtime)!
	// A hidden document never starts an idle period; only the timeout runs it.
	document.update_the_visibility_state(.hidden)
	runtime.evaluate_host(r'globalThis.timedOut=[];requestIdleCallback(function(deadline){timedOut.push(deadline.didTimeout)},{timeout:5});')!
	deadline := time.sys_mono_now() + 2 * time.second
	mut event_loop := host.settings.responsible_event_loop()
	event_loop.spin_until(fn [runtime, deadline] () bool {
		return runtime.evaluate_host('timedOut.length>0') or { 'false' } == 'true' || time.sys_mono_now() >= deadline
	})
	timed_out := runtime.evaluate_host('JSON.stringify(timedOut)')!
	assert timed_out == '[true]', timed_out
}
