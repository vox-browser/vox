module main

import browserjs
import dom
import html
import json2
import math
import page
import time

const media_timeline_raw_owner_markup = '<!doctype html><style>
html,body{margin:0}#mtr-video{display:block;width:180px;height:60px}
#mtr-result{position:absolute;top:100px;left:0}
</style><form id="mtr-form"><video id="mtr-video"></video></form><div id="mtr-result">waiting</div>'

@[heap]
struct MediaTimelineRawOwnerObservation {
mut:
	events []&dom.Event
	targets []voidptr
}

fn media_timeline_raw_owner_fixture(markup string, source string) !(&BrowserApp, &dom.Document, &browserjs.Runtime) {
	mut owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{
		value: 'https://media-timeline-raw-owner.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [source], runtime, mut messages)
	assert messages == []
	mut app := &BrowserApp{
		page_model: owner
		document: document
		js_runtime: runtime
		viewport_width: 320
		viewport_height: 240
	}
	app.relayout(320, 240 + app.chrome_height())
	assert document.layout_is_up_to_date() && document.paintable_box() != none
	return app, document, runtime
}

fn media_timeline_raw_owner_take_task(document &dom.Document) ?&html.Task {
	mut queue := html.main_thread_event_loop().task_queue()
	return queue.take_first_runnable_matching(fn [document] (task &html.Task) bool {
		owner := task.document() or { return false }
		return task.source() == .media_element && voidptr(owner) == voidptr(document)
	})
}

fn media_timeline_raw_owner_drain(document &dom.Document) {
	mut count := 0
	for {
		task := media_timeline_raw_owner_take_task(document) or { break }
		count++
		assert count < 100
		task.execute()
	}
}

fn media_timeline_raw_owner_probe(mut runtime browserjs.Runtime, document &dom.Document) ! {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	handle := voidptr(&runtime)
	actual_true := runtime.evaluate_host_value('true')!
	runtime.define_value_host_function('__mediaTimelineRawOwnerContext', fn [settings, handle, actual_true] (_ voidptr, args []voidptr) !voidptr {
		owner := unsafe { &browserjs.Runtime(handle) }
		assert args.len == 0
		assert settings.realm().script_execution_depth > 0 && settings.realm().callback_execution_depth > 0
		assert owner.libjs_vm().has_running_execution_context()
		assert voidptr(html.current_principal_settings_object()) == voidptr(settings)
		assert voidptr(html.incumbent_settings_object()) == voidptr(settings)
		return actual_true
	})!
}

fn media_timeline_raw_owner_observe(element &dom.Element, observation &MediaTimelineRawOwnerObservation) {
	handle := voidptr(observation)
	callback := &dom.CallbackType{
		handle_event: fn [handle] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut saved := unsafe { &MediaTimelineRawOwnerObservation(handle) }
			assert event.type_name() in ['durationchange', 'timeupdate']
			assert event.interface_ == .event && event.is_trusted()
			// The handler algorithm applies exact false to the canceled flag,
			// including native timeline events whose cancelable flag is false.
			assert !event.bubbles() && !event.cancelable() && event.default_prevented()
			saved.events << event
			saved.targets << voidptr(event.target() or { panic('Native timeline event needs its owner') })
			return dom.js_undefined()
		}
	}
	for name in ['durationchange', 'timeupdate'] {
		unsafe { &dom.EventTarget(element) }.add_event_listener_without_options(name, dom.IDLEventListener.create(callback))
	}
}

fn media_timeline_raw_owner_event(mut runtime browserjs.Runtime, event &dom.Event, expression string) ! {
	wrapper := runtime.evaluate_host_value(expression)!
	assert voidptr(runtime.native_event(wrapper)!) == voidptr(event)
	assert runtime.javascript_event(event)! == wrapper
	assert event.is_trusted() && event.current_target() == none && event.event_phase() == 0
	assert runtime.evaluate_host('${expression}.currentTarget===null&&${expression}.eventPhase===Event.NONE&&window.event===undefined')! == 'true'
}

fn media_timeline_raw_owner_balance(runtime &browserjs.Runtime, document &dom.Document, exceptions int) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == exceptions
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_media_raw_durationchange_timeupdate_parsed_created_scopes_trusted_events_and_live_duration() {
	$if !darwin { return }
	body := r'mtrRuns++;mtrOrder.push(this.id+":"+event.type);mtrScopes.push(scopeKey);delete this.scopeKey;mtrScopes.push(scopeKey);delete document.scopeKey;mtrScopes.push(scopeKey);document.scopeKey="document";this.scopeKey=this.id==="mtr-video"?"parsed element":"created element";mtrSaved.push(event);mtrChecks.push(arguments.length===1&&event===arguments[0]&&(this===mtrVideo||this===mtrAudio)&&event.target===this&&event.currentTarget===this&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event&&document===mtrDocument&&getElementById("mtr-result")===mtrResult&&duration===30&&currentTime===0&&paused===true&&__mediaTimelineRawOwnerContext());getElementById("mtr-result").textContent="raw media timeline painted";this.style.color="rgb(0,128,0)";return false;'
	attribute_body := body.replace('"', '&quot;')
	markup := media_timeline_raw_owner_markup.replace('<video id="mtr-video">',
		'<video id="mtr-video" ondurationchange="${attribute_body}" ontimeupdate="${attribute_body}">')
	mut app, mut document, mut runtime := media_timeline_raw_owner_fixture(markup, r'
globalThis.mtrVideo=document.getElementById("mtr-video");globalThis.mtrDocument=document;globalThis.mtrResult=document.getElementById("mtr-result");globalThis.mtrForm=document.getElementById("mtr-form");
globalThis.mtrRuns=0;globalThis.mtrOrder=[];globalThis.mtrScopes=[];globalThis.mtrSaved=[];globalThis.mtrChecks=[];globalThis.scopeKey="global";
document.scopeKey="document";mtrForm.scopeKey="nearest form";mtrVideo.scopeKey="parsed element";mtrVideo.event={sentinel:true};document.event={sentinel:true};
globalThis.mtrAudio=document.createElement("audio");mtrAudio.id="mtr-audio";mtrAudio.setAttribute("ondurationchange",mtrVideo.getAttribute("ondurationchange"));mtrAudio.setAttribute("ontimeupdate",mtrVideo.getAttribute("ontimeupdate"));document.body.appendChild(mtrAudio);mtrAudio.scopeKey="created element";void mtrAudio.paused;0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	media_timeline_raw_owner_probe(mut runtime, document)!
	video := document.get_element_by_id('mtr-video')?
	audio := document.get_element_by_id('mtr-audio')?
	native_video := unsafe { &dom.EventTarget(video) }
	native_audio := unsafe { &dom.EventTarget(audio) }
	for target in [native_video, native_audio] {
		for name in ['durationchange', 'timeupdate'] {
			slot := target.data.event_handler(name) or { panic('Raw timeline slot missing') }
			assert slot.value.kind == .string && slot.value.string_data == body
		}
	}
	assert runtime.evaluate_host(r'
globalThis.mtrVideoDuration=mtrVideo.ondurationchange;globalThis.mtrVideoTime=mtrVideo.ontimeupdate;globalThis.mtrAudioDuration=mtrAudio.ondurationchange;globalThis.mtrAudioTime=mtrAudio.ontimeupdate;
[mtrVideoDuration,mtrVideoTime,mtrAudioDuration,mtrAudioTime].every(value=>typeof value==="function"&&value.length===1)&&mtrVideoDuration.name==="ondurationchange"&&mtrAudioDuration.name==="ondurationchange"&&mtrVideoTime.name==="ontimeupdate"&&mtrAudioTime.name==="ontimeupdate"&&new Set([mtrVideoDuration,mtrVideoTime,mtrAudioDuration,mtrAudioTime]).size===4&&mtrVideo.ondurationchange===mtrVideoDuration&&mtrVideo.ontimeupdate===mtrVideoTime&&mtrAudio.ondurationchange===mtrAudioDuration&&mtrAudio.ontimeupdate===mtrAudioTime&&!Object.hasOwn(mtrVideo,"ondurationchange")&&!Object.hasOwn(mtrAudio,"ontimeupdate")&&mtrRuns===0
')! == 'true'
	actual_true := runtime.evaluate_host_value('true')!
	for target in [native_video, native_audio] {
		alias := if voidptr(target) == voidptr(native_video) { 'mtrVideo' } else { 'mtrAudio' }
		for name in ['durationchange', 'timeupdate'] {
			callback := target.get_current_value_of_event_handler(name) or { panic('Cached timeline callback missing') }
			assert callback.compiled_source_text_ == 'function on${name}(event) {\n${body}\n}'
			assert runtime.javascript_event_handler(target, name)! == runtime.evaluate_host_value('${alias}.on${name}')!
		}
		media := html.html_media_element_for_dom_element(unsafe { &dom.Element(target) }) or { panic('Timeline media owner missing') }
		media_handle := voidptr(media)
		// Duration is readonly in JavaScript. This test bridge enters the actual
		// native duration and time-marches-on algorithms on each DOM owner.
		runtime.define_value_host_function('__${alias}NativeTimeline', fn [media_handle, actual_true] (_ voidptr, args []voidptr) !voidptr {
			assert args.len == 0
			mut current_media := unsafe { &html.HTMLMediaElement(media_handle) }
			current_media.set_duration(20)
			current_media.set_duration(20)
			current_media.time_marches_on(.normal_playback)
			current_media.set_duration(30)
			return actual_true
		})!
	}
	observation := &MediaTimelineRawOwnerObservation{}
	media_timeline_raw_owner_observe(video, observation)
	media_timeline_raw_owner_observe(audio, observation)
	// A known duration queues even when equal. Every queued callback reads the
	// final duration, preserving the relative order of the native algorithms.
	assert runtime.evaluate_host('__mtrVideoNativeTimeline()&&__mtrAudioNativeTimeline()&&mtrRuns===0&&mtrSaved.length===0&&mtrOrder.length===0&&mtrVideo.duration===30&&mtrAudio.duration===30')! == 'true'
	media_timeline_raw_owner_drain(document)
	assert media_timeline_raw_owner_take_task(document) == none
	assert runtime.evaluate_host(r'
mtrRuns===8&&mtrOrder.join(",")==="mtr-video:durationchange,mtr-video:durationchange,mtr-video:timeupdate,mtr-video:durationchange,mtr-audio:durationchange,mtr-audio:durationchange,mtr-audio:timeupdate,mtr-audio:durationchange"&&mtrScopes.join(",")===[...Array(4).fill("parsed element,document,global"),...Array(4).fill("created element,document,global")].join(",")&&mtrChecks.length===8&&mtrChecks.every(Boolean)&&mtrSaved.every(event=>event.defaultPrevented)&&mtrForm.scopeKey==="nearest form"&&mtrVideo.ondurationchange===mtrVideoDuration&&mtrVideo.ontimeupdate===mtrVideoTime&&mtrAudio.ondurationchange===mtrAudioDuration&&mtrAudio.ontimeupdate===mtrAudioTime&&window.event===undefined
')! == 'true'
	assert observation.events.len == 8
	for index, event in observation.events {
		if index < 4 {
			assert observation.targets[index] == voidptr(video)
		} else {
			assert observation.targets[index] == voidptr(audio)
		}
		media_timeline_raw_owner_event(mut runtime, event, 'mtrSaved[${index}]')!
	}
	video_media := html.html_media_element_for_dom_element(video) or { panic('Video timeline owner missing') }
	audio_media := html.html_media_element_for_dom_element(audio) or { panic('Audio timeline owner missing') }
	assert video_media.event_count('durationchange') == 3 && video_media.event_count('timeupdate') == 1
	assert audio_media.event_count('durationchange') == 3 && audio_media.event_count('timeupdate') == 1
	app.poll_javascript_tasks()
	assert document.get_element_by_id('mtr-result')?.text_content()? == 'raw media timeline painted'
	assert video.get_attribute_value('style').contains('color') && audio.get_attribute_value('style').contains('color')
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'raw media timeline painted').len > 0
	assert app.js_messages == []
	media_timeline_raw_owner_balance(runtime, document, 0)
}

fn test_media_raw_timeline_live_equal_attributes_prequeued_replacement_running_guard_and_removal() {
	$if !darwin { return }
	body := r'mtrOrder.push("original-"+event.type);mtrSaved.push(event);return false;'
	attribute_body := body.replace('"', '&quot;')
	markup := media_timeline_raw_owner_markup.replace('<video id="mtr-video">',
		'<video id="mtr-video" ondurationchange="${attribute_body}" ontimeupdate="${attribute_body}">')
	mut app, mut document, mut runtime := media_timeline_raw_owner_fixture(markup, r'
globalThis.mtrVideo=document.getElementById("mtr-video");globalThis.mtrOrder=[];globalThis.mtrSaved=[];globalThis.mtrChecks=[];globalThis.mtrSource=mtrVideo.getAttribute("ondurationchange");globalThis.mtrFirstDuration=mtrVideo.ondurationchange;globalThis.mtrFirstTime=mtrVideo.ontimeupdate;
globalThis.mtrDurationIDL=function(event){mtrOrder.push("idl-duration");mtrSaved.push(event);mtrChecks.push(this===mtrVideo&&event.isTrusted&&window.event===event&&this.currentTime===0);return false};
globalThis.mtrTimeIDL=function(event){mtrOrder.push("idl-time");mtrSaved.push(event);mtrChecks.push(this===mtrVideo&&event.isTrusted&&window.event===event&&this.currentTime===0);return false};0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	video := document.get_element_by_id('mtr-video')?
	native_video := unsafe { &dom.EventTarget(video) }
	duration_slot := native_video.data.event_handler('durationchange') or { panic('Duration slot missing') }
	time_slot := native_video.data.event_handler('timeupdate') or { panic('Time slot missing') }
	duration_listener := duration_slot.listener or { panic('Duration listener missing') }
	time_listener := time_slot.listener or { panic('Time listener missing') }
	first_duration := native_video.get_current_value_of_event_handler('durationchange') or { panic('First duration callback missing') }
	first_time := native_video.get_current_value_of_event_handler('timeupdate') or { panic('First time callback missing') }
	assert runtime.evaluate_host(r'
mtrVideo.ondurationchange=mtrDurationIDL;mtrVideo.setAttribute("ondurationchange",mtrSource);globalThis.mtrSecondDuration=mtrVideo.ondurationchange;
mtrVideo.ontimeupdate=mtrTimeIDL;mtrVideo.setAttribute("ontimeupdate",mtrSource);globalThis.mtrSecondTime=mtrVideo.ontimeupdate;
typeof mtrSecondDuration==="function"&&mtrSecondDuration!==mtrFirstDuration&&mtrSecondDuration!==mtrDurationIDL&&mtrSecondDuration.name==="ondurationchange"&&mtrSecondDuration.length===1&&typeof mtrSecondTime==="function"&&mtrSecondTime!==mtrFirstTime&&mtrSecondTime!==mtrTimeIDL&&mtrSecondTime.name==="ontimeupdate"&&mtrSecondTime.length===1&&mtrVideo.ondurationchange===mtrSecondDuration&&mtrVideo.ontimeupdate===mtrSecondTime&&mtrOrder.length===0
')! == 'true'
	assert voidptr(native_video.data.event_handler('durationchange') or { panic('Replaced duration slot missing') }) == voidptr(duration_slot)
	assert voidptr(native_video.data.event_handler('timeupdate') or { panic('Replaced time slot missing') }) == voidptr(time_slot)
	assert voidptr(duration_slot.listener or { panic('Replaced duration listener missing') }) == voidptr(duration_listener)
	assert voidptr(time_slot.listener or { panic('Replaced time listener missing') }) == voidptr(time_listener)
	second_duration := native_video.get_current_value_of_event_handler('durationchange') or { panic('Second duration callback missing') }
	second_time := native_video.get_current_value_of_event_handler('timeupdate') or { panic('Second time callback missing') }
	assert voidptr(second_duration) != voidptr(first_duration) && second_duration.compiled_source_text_ == first_duration.compiled_source_text_
	assert voidptr(second_time) != voidptr(first_time) && second_time.compiled_source_text_ == first_time.compiled_source_text_
	mut media := html.html_media_element_for_dom_element(video) or { panic('Replacement timeline media owner missing') }
	media_handle := voidptr(media)
	actual_true := runtime.evaluate_host_value('true')!
	runtime.define_value_host_function('__mediaTimelineRawAppendDuration', fn [media_handle, actual_true] (_ voidptr, args []voidptr) !voidptr {
		assert args.len == 0
		mut current_media := unsafe { &html.HTMLMediaElement(media_handle) }
		current_media.set_duration(30)
		return actual_true
	})!
	runtime.define_value_host_function('__mediaTimelineRawRunningGuard', fn [media_handle, actual_true] (_ voidptr, args []voidptr) !voidptr {
		assert args.len == 0
		start := time.sys_mono_now()
		time.sleep(310 * time.millisecond)
		assert time.sys_mono_now() - start >= 300_000_000
		mut current_media := unsafe { &html.HTMLMediaElement(media_handle) }
		// The interval has elapsed while the raw handler remains on the stack.
		// Suppression here therefore exercises the running-handler guard.
		current_media.time_marches_on(.normal_playback)
		return actual_true
	})!
	media.set_duration(20)
	media.time_marches_on(.normal_playback)
	queued_duration_body := r'mtrOrder.push("replacement-duration");mtrSaved.push(event);mtrChecks.push(event.isTrusted&&this===mtrVideo&&this.duration===20&&window.event===event);mtrChecks.push(__mediaTimelineRawAppendDuration()&&mtrSaved.length===1);this.ondurationchange=mtrDurationIDL;return false;'
	queued_time_body := r'mtrOrder.push("replacement-time");mtrSaved.push(event);mtrChecks.push(event.isTrusted&&this===mtrVideo&&this.duration===30&&this.currentTime===0&&window.event===event);mtrChecks.push(__mediaTimelineRawRunningGuard()&&mtrSaved.length===2);this.ontimeupdate=mtrTimeIDL;document.getElementById("mtr-result").textContent="reentrant media timeline painted";return false;'
	assert runtime.evaluate_host('mtrVideo.setAttribute("ondurationchange",${json2.encode(queued_duration_body)});mtrVideo.setAttribute("ontimeupdate",${json2.encode(queued_time_body)});mtrVideo.paused&&mtrOrder.length===0')! == 'true'
	assert duration_slot.value.kind == .string && duration_slot.value.string_data == queued_duration_body
	assert time_slot.value.kind == .string && time_slot.value.string_data == queued_time_body
	(media_timeline_raw_owner_take_task(document) or { panic('Missing queued duration task') }).execute()
	assert runtime.evaluate_host('mtrOrder.join(",")==="replacement-duration"&&mtrSaved.length===1&&mtrVideo.duration===30')! == 'true'
	media_timeline_raw_owner_drain(document)
	assert media_timeline_raw_owner_take_task(document) == none
	assert runtime.evaluate_host('mtrOrder.join(",")==="replacement-duration,replacement-time,idl-duration"&&mtrSaved.length===3&&mtrSaved.every(event=>event.isTrusted&&event.defaultPrevented)&&mtrChecks.length===5&&mtrChecks.every(Boolean)&&mtrVideo.ondurationchange===mtrDurationIDL&&mtrVideo.ontimeupdate===mtrTimeIDL&&window.event===undefined')! == 'true'
	assert media.event_count('durationchange') == 2 && media.event_count('timeupdate') == 1
	// NaN is the loading reset value and adds no duration event. After the
	// guarded callback returns, its elapsed interval permits a fresh time task.
	media.set_duration(math.nan())
	assert media_timeline_raw_owner_take_task(document) == none
	assert runtime.evaluate_host('Number.isNaN(mtrVideo.duration)&&mtrOrder.length===3')! == 'true'
	media.time_marches_on(.normal_playback)
	(media_timeline_raw_owner_take_task(document) or { panic('Missing post-handler time task') }).execute()
	assert media_timeline_raw_owner_take_task(document) == none
	assert runtime.evaluate_host('mtrOrder.join(",")==="replacement-duration,replacement-time,idl-duration,idl-time"&&mtrSaved.length===4&&mtrChecks.length===6&&mtrChecks.every(Boolean)')! == 'true'
	assert media.event_count('durationchange') == 2 && media.event_count('timeupdate') == 2
	// Remove present content attributes after queuing, clearing both IDL values.
	media.set_duration(40)
	time.sleep(310 * time.millisecond)
	media.time_marches_on(.normal_playback)
	assert runtime.evaluate_host('mtrVideo.removeAttribute("ondurationchange");mtrVideo.removeAttribute("ontimeupdate");mtrVideo.ondurationchange===null&&mtrVideo.ontimeupdate===null&&mtrOrder.length===4')! == 'true'
	assert !native_video.data.has_event_handler('durationchange') && !native_video.data.has_event_handler('timeupdate')
	assert video.get_attribute('ondurationchange') == none && video.get_attribute('ontimeupdate') == none
	media_timeline_raw_owner_drain(document)
	assert runtime.evaluate_host('mtrOrder.length===4&&mtrSaved.length===4')! == 'true'
	// Removing already absent attributes preserves subsequently assigned IDL.
	assert runtime.evaluate_host('mtrVideo.ondurationchange=mtrDurationIDL;mtrVideo.ontimeupdate=mtrTimeIDL;mtrVideo.removeAttribute("ondurationchange");mtrVideo.removeAttribute("ontimeupdate");mtrVideo.ondurationchange===mtrDurationIDL&&mtrVideo.ontimeupdate===mtrTimeIDL')! == 'true'
	media.set_duration(50)
	time.sleep(310 * time.millisecond)
	media.time_marches_on(.normal_playback)
	media_timeline_raw_owner_drain(document)
	assert runtime.evaluate_host('mtrOrder.join(",")==="replacement-duration,replacement-time,idl-duration,idl-time,idl-duration,idl-time"&&mtrChecks.length===8&&mtrChecks.every(Boolean)&&mtrSaved.length===6&&mtrSaved.every(event=>event.isTrusted&&event.defaultPrevented)&&mtrVideo.ondurationchange===mtrDurationIDL&&mtrVideo.ontimeupdate===mtrTimeIDL&&window.event===undefined')! == 'true'
	assert native_video.event_listener_list().len == 2
	assert media.event_count('durationchange') == 4 && media.event_count('timeupdate') == 4
	for index in 0 .. 6 {
		event := runtime.native_event(runtime.evaluate_host_value('mtrSaved[${index}]')!)!
		media_timeline_raw_owner_event(mut runtime, event, 'mtrSaved[${index}]')!
	}
	app.poll_javascript_tasks()
	assert document.get_element_by_id('mtr-result')?.text_content()? == 'reentrant media timeline painted'
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'reentrant media timeline painted').len > 0
	assert app.js_messages == []
	media_timeline_raw_owner_balance(runtime, document, 0)
}

fn test_media_raw_timeline_scripting_gate_strict_original_exception_and_later_owner_listener() {
	$if !darwin { return }
	mut app, mut document, mut runtime := media_timeline_raw_owner_fixture(media_timeline_raw_owner_markup, r'
globalThis.mtrVideo=document.getElementById("mtr-video");globalThis.mtrRuns=0;globalThis.mtrTimeRuns=0;globalThis.mtrChecks=[];globalThis.mtrSaved=[];globalThis.mtrReason={original:true};globalThis.mtrOrder=[];mtrVideo.event={sentinel:true};document.event={sentinel:true};0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	media_timeline_raw_owner_probe(mut runtime, document)!
	video := document.get_element_by_id('mtr-video')?
	native_video := unsafe { &dom.EventTarget(video) }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut media := html.html_media_element_for_dom_element(video) or { panic('Gated timeline media owner missing') }
	body := r'"use strict";mtrRuns++;mtrOrder.push("strict-duration");mtrSaved.push(event);mtrChecks.push(arguments.length===1&&event===arguments[0]&&this===mtrVideo&&event.target===mtrVideo&&event.currentTarget===mtrVideo&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event&&this.duration===30&&this.currentTime===0&&__mediaTimelineRawOwnerContext());try{void arguments.callee;mtrChecks.push(false)}catch(error){mtrChecks.push(error instanceof TypeError)}this.ondurationchange=null;globalThis.mtrLiveName=ondurationchange;throw mtrReason;'
	time_body := r'mtrTimeRuns++;mtrOrder.push("raw-time");mtrSaved.push(event);mtrChecks.push(event.isTrusted&&this===mtrVideo&&window.event===event&&this.duration===30&&this.currentTime===0&&__mediaTimelineRawOwnerContext());return false;'
	assert runtime.evaluate_host('mtrVideo.setAttribute("ondurationchange",${json2.encode(body)});mtrVideo.setAttribute("ontimeupdate",${json2.encode(time_body)});mtrVideo.paused')! == 'true'
	duration_slot := native_video.data.event_handler('durationchange') or { panic('Strict duration slot missing') }
	time_slot := native_video.data.event_handler('timeupdate') or { panic('Raw time slot missing') }
	mut owner := app.page_model
	owner.set_is_scripting_enabled(false)
	media.set_duration(20)
	media.time_marches_on(.normal_playback)
	assert runtime.evaluate_host('mtrVideo.ondurationchange===null&&mtrVideo.ontimeupdate===null&&mtrRuns===0&&mtrTimeRuns===0')! == 'true'
	media_timeline_raw_owner_drain(document)
	assert duration_slot.value.kind == .string && duration_slot.value.string_data == body
	assert time_slot.value.kind == .string && time_slot.value.string_data == time_body
	assert runtime.evaluate_host('mtrRuns===0&&mtrTimeRuns===0&&mtrSaved.length===0&&mtrOrder.length===0')! == 'true'
	media_timeline_raw_owner_balance(runtime, document, 0)
	owner.set_is_scripting_enabled(true)
	assert runtime.evaluate_host(r'
globalThis.mtrStrict=mtrVideo.ondurationchange;globalThis.mtrTime=mtrVideo.ontimeupdate;
mtrVideo.addEventListener("durationchange",function(event){mtrOrder.push("later-duration");globalThis.mtrLater=this===mtrVideo&&event.currentTarget===mtrVideo&&event.isTrusted&&!event.defaultPrevented&&window.event===event&&this.duration===30;document.getElementById("mtr-result").textContent="later media duration listener"});typeof mtrStrict==="function"&&mtrStrict.name==="ondurationchange"&&mtrStrict.length===1&&mtrVideo.ondurationchange===mtrStrict&&typeof mtrTime==="function"&&mtrTime.name==="ontimeupdate"&&mtrVideo.ontimeupdate===mtrTime&&mtrRuns===0
')! == 'true'
	strict_callback := native_video.get_current_value_of_event_handler('durationchange') or { panic('Strict duration callback missing') }
	assert strict_callback.compiled_source_text_ == 'function ondurationchange(event) {\n${body}\n}'
	assert runtime.javascript_event_handler(native_video, 'durationchange')! == runtime.evaluate_host_value('mtrStrict')!
	media.set_duration(30)
	time.sleep(310 * time.millisecond)
	media.time_marches_on(.normal_playback)
	assert runtime.evaluate_host('mtrOrder.length===0')! == 'true'
	(media_timeline_raw_owner_take_task(document) or { panic('Missing strict duration task') }).execute()
	assert runtime.evaluate_host('mtrOrder.join(",")==="strict-duration,later-duration"&&mtrRuns===1&&mtrTimeRuns===0&&mtrLiveName===null&&mtrVideo.ondurationchange===null&&mtrLater&&mtrChecks.length===2&&mtrChecks.every(Boolean)&&window.event===undefined')! == 'true'
	assert !native_video.data.has_event_handler('durationchange') && native_video.data.has_event_handler('timeupdate')
	assert video.get_attribute_value('ondurationchange') == body && video.get_attribute_value('ontimeupdate') == time_body
	assert settings.realm().reported_exceptions.len == 1
	reported := settings.realm().reported_exceptions[0].value.as_webidl_value()!
	assert runtime.actual_webidl_value(reported)! == runtime.evaluate_host_value('mtrReason')!
	media_timeline_raw_owner_drain(document)
	assert runtime.evaluate_host('mtrRuns===1&&mtrTimeRuns===1&&mtrChecks.length===3&&mtrChecks.every(Boolean)&&mtrVideo.ontimeupdate===mtrTime&&mtrSaved.length===2&&!mtrSaved[0].defaultPrevented&&mtrSaved[1].defaultPrevented&&mtrOrder.join(",")==="strict-duration,later-duration,raw-time"&&window.event===undefined')! == 'true'
	assert media.event_count('durationchange') == 2 && media.event_count('timeupdate') == 2
	for index in 0 .. 2 {
		event := runtime.native_event(runtime.evaluate_host_value('mtrSaved[${index}]')!)!
		media_timeline_raw_owner_event(mut runtime, event, 'mtrSaved[${index}]')!
	}
	app.poll_javascript_tasks()
	assert document.get_element_by_id('mtr-result')?.text_content()? == 'later media duration listener'
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'later media duration listener').len > 0
	assert app.js_messages == []
	media_timeline_raw_owner_balance(runtime, document, 1)
}

