module browserjs

import dom
import html
import highresolutiontime
import page

fn frame_host_document() (&dom.Document, &page.Page) {
	mut document := html.parse_navigation_document('<!doctype html><body></body>', dom.URL{value: 'https://frame-host.test/'},
		dom.URL{value: 'https://frame-host.test/'}.origin(), none) or { panic(err) }
	mut page_ := page.Page.create(1) or { panic(err) }
	document.set_page(unsafe { &dom.Page(page_) })
	page_.set_local_root_navigable(document.navigable() or { panic('missing navigable') }) or {
		panic(err)
	}
	document.load_timing_info.navigation_start_time =
		highresolutiontime.unsafe_shared_current_time()
	document.update_the_visibility_state(.visible)
	return document, page_
}

fn frame_host_opportunity(host &AnimationFrameHost, page_ &page.Page) {
	absolute := highresolutiontime.unsafe_shared_current_time()
	mut client := page_.client()
	client.rendering_opportunity(i64(absolute * 1e6), 16)
	mut event_loop := unsafe { &html.EventLoop(host.settings.responsible_event_loop()) }
	event_loop.rendering_opportunity(absolute, false)
	for event_loop.task_queue().has_runnable_tasks() {
		event_loop.process()
	}
}

fn test_native_frame_callback_uses_real_rendering_task_document_origin_receiver_and_synchronous_return() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	mut document, page_ := frame_host_document()
	defer {
		runtime.close()
		document.finalize()
	}
	mut host := AnimationFrameHost.create(document, none)!
	host.install(mut runtime)!
	owner_handle := voidptr(&runtime)
	settings := host.settings
	runtime.define_value_host_function('__frameOwner', fn [settings, owner_handle] (_ voidptr, _ []voidptr) !voidptr {
		runtime := unsafe { &Runtime(owner_handle) }
		loop := settings.responsible_event_loop()
		assert (loop.currently_running_task() or { panic('missing rendering task') }).source() == .rendering
		assert loop.running_rendering_task()
		assert settings.realm().script_execution_depth >= 1
			&& settings.realm().callback_execution_depth >= 1
		assert voidptr(html.incumbent_settings_object()) == voidptr(settings)
		return C.vox_jsc_JSValueMakeBoolean(runtime.context, true)
	})!
	before_roots := runtime.protected_values_.len
	runtime.evaluate_host(r'globalThis.frameThenAccesses=0;globalThis.frameCalls=[];globalThis.frameId=requestAnimationFrame(function(now){"use strict";frameCalls.push([now,this===undefined,__frameOwner()]);return {get then(){frameThenAccesses++;throw "must not read then"}}});')!
	assert runtime.evaluate_host('frameId>0&&Number.isInteger(frameId)&&frameCalls.length===0')! == 'true'
	assert runtime.protected_values_.len == before_roots + 1
	frame_host_opportunity(host, page_)
	assert runtime.evaluate_host('frameCalls.length===1&&frameCalls[0][1]&&frameCalls[0][2]')! == 'true'
	assert runtime.evaluate_host('frameCalls[0][0]')!.f64() == document.last_animation_frame_timestamp?
	assert document.last_animation_frame_timestamp? >= 0
	assert document.last_animation_frame_timestamp? < 10000
	assert runtime.evaluate_host('frameThenAccesses')! == '0'
	assert runtime.protected_values_.len == before_roots
	assert !host.window.has_animation_frame_callbacks()
	assert runtime.take_document_state_dirty()
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
}

fn test_native_frame_pending_and_executing_cancellation_release_callback_roots() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	mut document, page_ := frame_host_document()
	defer {
		runtime.close()
		document.finalize()
	}
	mut host := AnimationFrameHost.create(document, none)!
	host.install(mut runtime)!
	baseline := runtime.protected_values_.len
	runtime.evaluate_host(r'globalThis.order=[];globalThis.orderTimes=[];const cancelled=requestAnimationFrame(()=>order.push("cancelled"));cancelAnimationFrame(cancelled);let second;requestAnimationFrame(now=>{order.push("first");orderTimes.push(now);cancelAnimationFrame(second);requestAnimationFrame(later=>{order.push("nested");orderTimes.push(later)});const pending=requestAnimationFrame(()=>order.push("cancelled-nested"));cancelAnimationFrame(pending)});second=requestAnimationFrame(now=>{order.push("second");orderTimes.push(now)});')!
	assert runtime.protected_values_.len == baseline + 2
	frame_host_opportunity(host, page_)
	assert runtime.evaluate_host('order.join(",")')! == 'first'
	assert runtime.protected_values_.len == baseline + 1
	assert host.window.has_animation_frame_callbacks()
	frame_host_opportunity(host, page_)
	assert runtime.evaluate_host('order.join(",")')! == 'first,nested'
	assert runtime.evaluate_host('orderTimes[1]>=orderTimes[0]')! == 'true'
	assert runtime.protected_values_.len == baseline
}

fn test_native_frame_eligibility_defers_hidden_and_suppressed_documents_and_reports_actual_reasons() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	mut document, page_ := frame_host_document()
	defer {
		runtime.close()
		document.finalize()
	}
	mut host := AnimationFrameHost.create(document, none)!
	host.install(mut runtime)!
	actual :=
		runtime.evaluate_host_value('globalThis.frameReason={toString(){throw "must not coerce reason"}};frameReason')!
	runtime.evaluate_host('globalThis.afterThrow=false;requestAnimationFrame(()=>{throw frameReason});requestAnimationFrame(()=>{afterThrow=true})')!
	document.update_the_visibility_state(.hidden)
	frame_host_opportunity(host, page_)
	assert host.window.has_animation_frame_callbacks()
	assert runtime.evaluate_host('afterThrow')! == 'false'
	document.update_the_visibility_state(.visible)
	document.rendering_suppression_for_view_transitions = true
	frame_host_opportunity(host, page_)
	assert host.settings.realm().reported_exceptions.len == 0
	document.rendering_suppression_for_view_transitions = false
	body := unsafe { &dom.Element(document.body() or { panic('missing body') }) }
	document.add_render_blocking_element(body)
	frame_host_opportunity(host, page_)
	assert host.window.has_animation_frame_callbacks()
	assert host.settings.realm().reported_exceptions.len == 0
	document.remove_render_blocking_element(body)
	navigable := document.navigable() or { panic('missing active navigable') }
	document.set_cached_navigable(none)
	frame_host_opportunity(host, page_)
	assert host.window.has_animation_frame_callbacks()
	assert host.settings.realm().reported_exceptions.len == 0
	document.set_cached_navigable(navigable)
	frame_host_opportunity(host, page_)
	assert runtime.evaluate_host('afterThrow')! == 'true'
	assert host.settings.realm().reported_exceptions.len == 1
	reported := host.settings.realm().reported_exceptions[0]
	assert reported.error_in_promise == .no
	assert runtime.actual_webidl_value(reported.value.as_webidl_value()!)! == actual
}

fn test_native_frame_binding_validates_webidl_arguments_original_conversion_errors_and_close_lifetime() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	mut document, page_ := frame_host_document()
	defer { document.finalize() }
	mut host := AnimationFrameHost.create(document, none)!
	host.install(mut runtime)!
	assert runtime.evaluate_host(r'const marker={};let same=false;try{cancelAnimationFrame({valueOf(){throw marker}})}catch(reason){same=reason===marker}const invalid=[()=>requestAnimationFrame(),()=>requestAnimationFrame(1),()=>requestAnimationFrame.call({},()=>{}),()=>cancelAnimationFrame(),()=>cancelAnimationFrame(1n),()=>cancelAnimationFrame(Symbol()),()=>cancelAnimationFrame.call({},0)];same&&invalid.every(fn=>{try{fn();return false}catch(error){return error instanceof TypeError}})&&requestAnimationFrame.length===1&&cancelAnimationFrame.length===1')! == 'true'
	baseline := runtime.protected_values_.len
	runtime.evaluate_host('const id=requestAnimationFrame(()=>{});cancelAnimationFrame(id+4294967296.75);cancelAnimationFrame(undefined);cancelAnimationFrame(NaN)')!
	assert !host.window.has_animation_frame_callbacks()
	assert runtime.protected_values_.len == baseline
	mut observed := &FrameCloseObservation{}
	mut window := unsafe { &html.WindowModel(host.window) }
	window.request_animation_frame(fn [mut observed] (_ f64) {
		observed.ran = true
	})
	runtime.evaluate_host('requestAnimationFrame(()=>{throw "closed callback"})')!
	runtime.close()
	assert host.closed
	assert window.has_animation_frame_callbacks()
	frame_host_opportunity(host, page_)
	assert observed.ran
	assert !window.has_animation_frame_callbacks()
	assert host.settings.realm().reported_exceptions.len == 0
}

@[heap]
struct FrameCloseObservation {
mut:
	ran bool
}
