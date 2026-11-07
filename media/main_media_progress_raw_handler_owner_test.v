module main

import browserjs
import dom
import html
import json2
import page
import time

const media_progress_raw_owner_markup = '<!doctype html><style>
html,body{margin:0}#mpr-video{display:block;width:180px;height:60px}
#mpr-result{position:absolute;top:100px;left:0}
</style><form id="mpr-form"><video id="mpr-video"></video></form><div id="mpr-result">waiting</div>'

@[heap]
struct MediaProgressRawOwnerObservation {
mut:
	events []&dom.Event
	targets []voidptr
}

fn media_progress_raw_owner_fixture(markup string, source string) !(&BrowserApp, &dom.Document, &browserjs.Runtime) {
	mut owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{
		value: 'https://media-progress-raw-owner.example.test/'
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

fn media_progress_raw_owner_take_task(document &dom.Document) ?&html.Task {
	mut queue := html.main_thread_event_loop().task_queue()
	return queue.take_first_runnable_matching(fn [document] (task &html.Task) bool {
		owner := task.document() or { return false }
		return task.source() == .media_element && voidptr(owner) == voidptr(document)
	})
}

fn media_progress_raw_owner_drain(document &dom.Document) {
	mut count := 0
	for {
		task := media_progress_raw_owner_take_task(document) or { break }
		count++
		assert count < 100
		task.execute()
	}
}

fn media_progress_raw_owner_probe(mut runtime browserjs.Runtime, document &dom.Document) ! {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	handle := voidptr(&runtime)
	actual_true := runtime.evaluate_host_value('true')!
	runtime.define_value_host_function('__mediaProgressRawOwnerContext', fn [settings, handle, actual_true] (_ voidptr, args []voidptr) !voidptr {
		owner := unsafe { &browserjs.Runtime(handle) }
		assert args.len == 0
		assert settings.realm().script_execution_depth > 0 && settings.realm().callback_execution_depth > 0
		assert owner.libjs_vm().has_running_execution_context()
		assert voidptr(html.current_principal_settings_object()) == voidptr(settings)
		assert voidptr(html.incumbent_settings_object()) == voidptr(settings)
		return actual_true
	})!
}

fn media_progress_raw_owner_observe(element &dom.Element, observation &MediaProgressRawOwnerObservation) {
	handle := voidptr(observation)
	callback := &dom.CallbackType{
		handle_event: fn [handle] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut saved := unsafe { &MediaProgressRawOwnerObservation(handle) }
			assert event.type_name() in ['progress', 'suspend']
			assert event.interface_ == .event && event.is_trusted()
			// The handler algorithm applies exact false to the canceled flag,
			// including native progress events whose cancelable flag is false.
			assert !event.bubbles() && !event.cancelable() && event.default_prevented()
			saved.events << event
			saved.targets << voidptr(event.target() or { panic('Native progress event needs its owner') })
			return dom.js_undefined()
		}
	}
	for name in ['progress', 'suspend'] {
		unsafe { &dom.EventTarget(element) }.add_event_listener_without_options(name, dom.IDLEventListener.create(callback))
	}
}

fn media_progress_raw_owner_event(mut runtime browserjs.Runtime, event &dom.Event, expression string) ! {
	wrapper := runtime.evaluate_host_value(expression)!
	assert voidptr(runtime.native_event(wrapper)!) == voidptr(event)
	assert runtime.javascript_event(event)! == wrapper
	assert event.is_trusted() && event.current_target() == none && event.event_phase() == 0
	assert runtime.evaluate_host('${expression}.currentTarget===null&&${expression}.eventPhase===Event.NONE&&window.event===undefined')! == 'true'
}

fn media_progress_raw_owner_balance(runtime &browserjs.Runtime, document &dom.Document, exceptions int) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == exceptions
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn media_progress_raw_owner_bridge(mut runtime browserjs.Runtime, media &html.HTMLMediaElement, name string, ongoing bool) ! {
	media_handle := voidptr(media)
	actual_true := runtime.evaluate_host_value('true')!
	runtime.define_value_host_function(name, fn [media_handle, actual_true, ongoing] (_ voidptr, args []voidptr) !voidptr {
		assert args.len == 0
		mut current_media := unsafe { &html.HTMLMediaElement(media_handle) }
		if ongoing { current_media.process_media_data(.ongoing) }
		// Deliver completion through the actual media task source. The native
		// completion algorithm dispatches progress, then idle/suspend in one task.
		current_media.queue_a_media_element_task(fn [media_handle] () {
			mut completed_media := unsafe { &html.HTMLMediaElement(media_handle) }
			completed_media.process_media_data(.complete)
		})
		return actual_true
	})!
}

fn test_media_raw_progress_suspend_parsed_created_scopes_trusted_events_and_completion_task_order() {
	$if !darwin { return }
	body := r'mprRuns++;mprOrder.push(this.id+":"+event.type);mprStates.push(networkState);mprScopes.push(scopeKey);delete this.scopeKey;mprScopes.push(scopeKey);delete document.scopeKey;mprScopes.push(scopeKey);document.scopeKey="document";this.scopeKey=this.id==="mpr-video"?"parsed element":"created element";mprSaved.push(event);mprChecks.push(arguments.length===1&&event===arguments[0]&&(this===mprVideo||this===mprAudio)&&event.target===this&&event.currentTarget===this&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event&&document===mprDocument&&getElementById("mpr-result")===mprResult&&networkState===(event.type==="progress"?2:1)&&readyState===0&&currentTime===0&&paused===true&&__mediaProgressRawOwnerContext());getElementById("mpr-result").textContent="raw media progress painted";this.style.color="rgb(0,128,0)";return false;'
	attribute_body := body.replace('"', '&quot;')
	markup := media_progress_raw_owner_markup.replace('<video id="mpr-video">',
		'<video id="mpr-video" onprogress="${attribute_body}" onsuspend="${attribute_body}">')
	mut app, mut document, mut runtime := media_progress_raw_owner_fixture(markup, r'
globalThis.mprVideo=document.getElementById("mpr-video");globalThis.mprDocument=document;globalThis.mprResult=document.getElementById("mpr-result");globalThis.mprForm=document.getElementById("mpr-form");
globalThis.mprRuns=0;globalThis.mprOrder=[];globalThis.mprStates=[];globalThis.mprScopes=[];globalThis.mprSaved=[];globalThis.mprChecks=[];globalThis.scopeKey="global";
document.scopeKey="document";mprForm.scopeKey="nearest form";mprVideo.scopeKey="parsed element";mprVideo.event={sentinel:true};document.event={sentinel:true};
globalThis.mprAudio=document.createElement("audio");mprAudio.id="mpr-audio";mprAudio.setAttribute("onprogress",mprVideo.getAttribute("onprogress"));mprAudio.setAttribute("onsuspend",mprVideo.getAttribute("onsuspend"));document.body.appendChild(mprAudio);mprAudio.scopeKey="created element";void mprAudio.paused;0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	media_progress_raw_owner_probe(mut runtime, document)!
	video := document.get_element_by_id('mpr-video')?
	audio := document.get_element_by_id('mpr-audio')?
	native_video := unsafe { &dom.EventTarget(video) }
	native_audio := unsafe { &dom.EventTarget(audio) }
	for target in [native_video, native_audio] {
		for name in ['progress', 'suspend'] {
			slot := target.data.event_handler(name) or { panic('Raw progress slot missing') }
			assert slot.value.kind == .string && slot.value.string_data == body
		}
	}
	assert runtime.evaluate_host(r'
globalThis.mprVideoProgress=mprVideo.onprogress;globalThis.mprVideoSuspend=mprVideo.onsuspend;globalThis.mprAudioProgress=mprAudio.onprogress;globalThis.mprAudioSuspend=mprAudio.onsuspend;
[mprVideoProgress,mprVideoSuspend,mprAudioProgress,mprAudioSuspend].every(value=>typeof value==="function"&&value.length===1)&&mprVideoProgress.name==="onprogress"&&mprAudioProgress.name==="onprogress"&&mprVideoSuspend.name==="onsuspend"&&mprAudioSuspend.name==="onsuspend"&&new Set([mprVideoProgress,mprVideoSuspend,mprAudioProgress,mprAudioSuspend]).size===4&&mprVideo.onprogress===mprVideoProgress&&mprVideo.onsuspend===mprVideoSuspend&&mprAudio.onprogress===mprAudioProgress&&mprAudio.onsuspend===mprAudioSuspend&&!Object.hasOwn(mprVideo,"onprogress")&&!Object.hasOwn(mprAudio,"onsuspend")&&mprRuns===0
')! == 'true'
	for target in [native_video, native_audio] {
		alias := if voidptr(target) == voidptr(native_video) { 'mprVideo' } else { 'mprAudio' }
		for name in ['progress', 'suspend'] {
			callback := target.get_current_value_of_event_handler(name) or { panic('Cached progress callback missing') }
			assert callback.compiled_source_text_ == 'function on${name}(event) {\n${body}\n}'
			assert runtime.javascript_event_handler(target, name)! == runtime.evaluate_host_value('${alias}.on${name}')!
		}
	}
	video_media := html.html_media_element_for_dom_element(video) or { panic('Video progress owner missing') }
	audio_media := html.html_media_element_for_dom_element(audio) or { panic('Audio progress owner missing') }
	media_progress_raw_owner_bridge(mut runtime, video_media, '__mediaProgressRawVideoStart', true)!
	media_progress_raw_owner_bridge(mut runtime, audio_media, '__mediaProgressRawAudioStart', true)!
	observation := &MediaProgressRawOwnerObservation{}
	media_progress_raw_owner_observe(video, observation)
	media_progress_raw_owner_observe(audio, observation)
	// Each fresh ongoing algorithm queues a loading task and its initial
	// progress task. No elapsed-time throttle assumption is needed here.
	assert runtime.evaluate_host('__mediaProgressRawVideoStart()&&__mediaProgressRawAudioStart()&&mprVideo.networkState===0&&mprAudio.networkState===0&&mprRuns===0&&mprSaved.length===0&&mprOrder.length===0')! == 'true'
	(media_progress_raw_owner_take_task(document) or { panic('Missing video loading task') }).execute()
	assert runtime.evaluate_host('mprVideo.networkState===2&&mprAudio.networkState===0&&mprRuns===0')! == 'true'
	(media_progress_raw_owner_take_task(document) or { panic('Missing video ongoing progress task') }).execute()
	assert runtime.evaluate_host('mprRuns===1&&mprOrder.join(",")==="mpr-video:progress"&&mprVideo.networkState===2&&mprAudio.networkState===0')! == 'true'
	// Both completion callbacks execute in this single native task. Returning
	// exact false from progress leaves the idle transition and suspend intact.
	(media_progress_raw_owner_take_task(document) or { panic('Missing video completion task') }).execute()
	assert runtime.evaluate_host('mprRuns===3&&mprOrder.join(",")==="mpr-video:progress,mpr-video:progress,mpr-video:suspend"&&mprStates.join(",")==="2,2,1"&&mprVideo.networkState===1&&mprAudio.networkState===0')! == 'true'
	(media_progress_raw_owner_take_task(document) or { panic('Missing audio loading task') }).execute()
	assert runtime.evaluate_host('mprAudio.networkState===2&&mprRuns===3')! == 'true'
	(media_progress_raw_owner_take_task(document) or { panic('Missing audio ongoing progress task') }).execute()
	assert runtime.evaluate_host('mprRuns===4&&mprOrder[3]==="mpr-audio:progress"&&mprAudio.networkState===2')! == 'true'
	(media_progress_raw_owner_take_task(document) or { panic('Missing audio completion task') }).execute()
	assert media_progress_raw_owner_take_task(document) == none
	assert runtime.evaluate_host(r'
mprRuns===6&&mprOrder.join(",")==="mpr-video:progress,mpr-video:progress,mpr-video:suspend,mpr-audio:progress,mpr-audio:progress,mpr-audio:suspend"&&mprStates.join(",")==="2,2,1,2,2,1"&&mprScopes.join(",")===[...Array(3).fill("parsed element,document,global"),...Array(3).fill("created element,document,global")].join(",")&&mprChecks.length===6&&mprChecks.every(Boolean)&&mprSaved.every(event=>event.defaultPrevented)&&mprForm.scopeKey==="nearest form"&&mprVideo.onprogress===mprVideoProgress&&mprVideo.onsuspend===mprVideoSuspend&&mprAudio.onprogress===mprAudioProgress&&mprAudio.onsuspend===mprAudioSuspend&&window.event===undefined
')! == 'true'
	assert observation.events.len == 6
	for index, event in observation.events {
		if index < 3 {
			assert observation.targets[index] == voidptr(video)
		} else {
			assert observation.targets[index] == voidptr(audio)
		}
		media_progress_raw_owner_event(mut runtime, event, 'mprSaved[${index}]')!
	}
	assert video_media.event_count('progress') == 2 && video_media.event_count('suspend') == 1
	assert audio_media.event_count('progress') == 2 && audio_media.event_count('suspend') == 1
	assert video_media.ready_state() == .have_nothing && audio_media.ready_state() == .have_nothing
	app.poll_javascript_tasks()
	assert document.get_element_by_id('mpr-result')?.text_content()? == 'raw media progress painted'
	assert video.get_attribute_value('style').contains('color') && audio.get_attribute_value('style').contains('color')
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'raw media progress painted').len > 0
	assert app.js_messages == []
	media_progress_raw_owner_balance(runtime, document, 0)
}

fn test_media_raw_progress_live_equal_attributes_prequeued_replacement_reentry_and_removal() {
	$if !darwin { return }
	body := r'mprOrder.push("original-"+event.type);mprSaved.push(event);return false;'
	attribute_body := body.replace('"', '&quot;')
	markup := media_progress_raw_owner_markup.replace('<video id="mpr-video">',
		'<video id="mpr-video" onprogress="${attribute_body}" onsuspend="${attribute_body}">')
	mut app, mut document, mut runtime := media_progress_raw_owner_fixture(markup, r'
globalThis.mprVideo=document.getElementById("mpr-video");globalThis.mprOrder=[];globalThis.mprStates=[];globalThis.mprSaved=[];globalThis.mprChecks=[];globalThis.mprSource=mprVideo.getAttribute("onprogress");globalThis.mprFirstProgress=mprVideo.onprogress;globalThis.mprFirstSuspend=mprVideo.onsuspend;
globalThis.mprProgressIDL=function(event){mprOrder.push("idl-progress");mprStates.push(this.networkState);mprSaved.push(event);mprChecks.push(this===mprVideo&&event.isTrusted&&window.event===event&&this.readyState===0&&this.currentTime===0&&this.paused);return false};
globalThis.mprSuspendIDL=function(event){mprOrder.push("idl-suspend");mprStates.push(this.networkState);mprSaved.push(event);mprChecks.push(this===mprVideo&&event.isTrusted&&window.event===event&&this.networkState===1&&this.readyState===0&&this.currentTime===0&&this.paused);return false};0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	media_progress_raw_owner_probe(mut runtime, document)!
	video := document.get_element_by_id('mpr-video')?
	native_video := unsafe { &dom.EventTarget(video) }
	progress_slot := native_video.data.event_handler('progress') or { panic('Progress slot missing') }
	suspend_slot := native_video.data.event_handler('suspend') or { panic('Suspend slot missing') }
	progress_listener := progress_slot.listener or { panic('Progress listener missing') }
	suspend_listener := suspend_slot.listener or { panic('Suspend listener missing') }
	first_progress := native_video.get_current_value_of_event_handler('progress') or { panic('First progress callback missing') }
	first_suspend := native_video.get_current_value_of_event_handler('suspend') or { panic('First suspend callback missing') }
	assert runtime.evaluate_host(r'
mprVideo.onprogress=mprProgressIDL;mprVideo.setAttribute("onprogress",mprSource);globalThis.mprSecondProgress=mprVideo.onprogress;
mprVideo.onsuspend=mprSuspendIDL;mprVideo.setAttribute("onsuspend",mprSource);globalThis.mprSecondSuspend=mprVideo.onsuspend;
typeof mprSecondProgress==="function"&&mprSecondProgress!==mprFirstProgress&&mprSecondProgress!==mprProgressIDL&&mprSecondProgress.name==="onprogress"&&mprSecondProgress.length===1&&typeof mprSecondSuspend==="function"&&mprSecondSuspend!==mprFirstSuspend&&mprSecondSuspend!==mprSuspendIDL&&mprSecondSuspend.name==="onsuspend"&&mprSecondSuspend.length===1&&mprVideo.onprogress===mprSecondProgress&&mprVideo.onsuspend===mprSecondSuspend&&mprOrder.length===0
')! == 'true'
	assert voidptr(native_video.data.event_handler('progress') or { panic('Replaced progress slot missing') }) == voidptr(progress_slot)
	assert voidptr(native_video.data.event_handler('suspend') or { panic('Replaced suspend slot missing') }) == voidptr(suspend_slot)
	assert voidptr(progress_slot.listener or { panic('Replaced progress listener missing') }) == voidptr(progress_listener)
	assert voidptr(suspend_slot.listener or { panic('Replaced suspend listener missing') }) == voidptr(suspend_listener)
	second_progress := native_video.get_current_value_of_event_handler('progress') or { panic('Second progress callback missing') }
	second_suspend := native_video.get_current_value_of_event_handler('suspend') or { panic('Second suspend callback missing') }
	assert voidptr(second_progress) != voidptr(first_progress) && second_progress.compiled_source_text_ == first_progress.compiled_source_text_
	assert voidptr(second_suspend) != voidptr(first_suspend) && second_suspend.compiled_source_text_ == first_suspend.compiled_source_text_
	media := html.html_media_element_for_dom_element(video) or { panic('Reentrant progress media owner missing') }
	media_progress_raw_owner_bridge(mut runtime, media, '__mediaProgressRawStart', true)!
	media_progress_raw_owner_bridge(mut runtime, media, '__mediaProgressRawComplete', false)!
	assert runtime.evaluate_host('__mediaProgressRawStart()&&mprOrder.length===0')! == 'true'
	queued_suspend_body := r'mprOrder.push("replacement-suspend");mprStates.push(this.networkState);mprSaved.push(event);mprChecks.push(event.isTrusted&&this===mprVideo&&this.networkState===1&&this.readyState===0&&this.currentTime===0&&this.paused&&window.event===event&&__mediaProgressRawOwnerContext());this.onsuspend=mprSuspendIDL;document.getElementById("mpr-result").textContent="reentrant media progress painted";return false;'
	queued_progress_body := r'mprOrder.push("replacement-progress");mprStates.push(this.networkState);mprSaved.push(event);mprChecks.push(event.isTrusted&&this===mprVideo&&this.networkState===2&&this.readyState===0&&this.currentTime===0&&this.paused&&window.event===event&&__mediaProgressRawOwnerContext());this.setAttribute("onsuspend",mprQueuedSuspendBody);void this.paused;mprChecks.push(__mediaProgressRawComplete()&&mprSaved.length===1);this.onprogress=mprProgressIDL;return false;'
	assert runtime.evaluate_host('globalThis.mprQueuedSuspendBody=${json2.encode(queued_suspend_body)};mprVideo.setAttribute("onprogress",${json2.encode(queued_progress_body)});mprVideo.paused&&mprOrder.length===0')! == 'true'
	assert progress_slot.value.kind == .string && progress_slot.value.string_data == queued_progress_body
	(media_progress_raw_owner_take_task(document) or { panic('Missing reentrant loading task') }).execute()
	(media_progress_raw_owner_take_task(document) or { panic('Missing replacement progress task') }).execute()
	assert runtime.evaluate_host('mprOrder.join(",")==="replacement-progress"&&mprSaved.length===1&&mprVideo.networkState===2&&mprVideo.onprogress===mprProgressIDL')! == 'true'
	assert suspend_slot.value.kind == .string && suspend_slot.value.string_data == queued_suspend_body
	// Replacement appends another real completion behind the original task.
	// Each completion reads the latest progress/suspend slots at dispatch time.
	(media_progress_raw_owner_take_task(document) or { panic('Missing original completion task') }).execute()
	assert runtime.evaluate_host('mprOrder.join(",")==="replacement-progress,idl-progress,replacement-suspend"&&mprStates.join(",")==="2,2,1"&&mprSaved.length===3&&mprVideo.onsuspend===mprSuspendIDL')! == 'true'
	(media_progress_raw_owner_take_task(document) or { panic('Missing reentrant completion task') }).execute()
	assert media_progress_raw_owner_take_task(document) == none
	assert runtime.evaluate_host('mprOrder.join(",")==="replacement-progress,idl-progress,replacement-suspend,idl-progress,idl-suspend"&&mprStates.join(",")==="2,2,1,1,1"&&mprSaved.length===5&&mprSaved.every(event=>event.isTrusted&&event.defaultPrevented)&&mprChecks.length===6&&mprChecks.every(Boolean)&&mprVideo.onprogress===mprProgressIDL&&mprVideo.onsuspend===mprSuspendIDL&&window.event===undefined')! == 'true'
	assert voidptr(suspend_slot.listener or { panic('Reentrant suspend listener missing') }) == voidptr(suspend_listener)
	assert media.event_count('progress') == 3 && media.event_count('suspend') == 2
	// Present removals clear IDL values before an already queued completion.
	assert runtime.evaluate_host('__mediaProgressRawComplete();mprVideo.removeAttribute("onprogress");mprVideo.removeAttribute("onsuspend");mprVideo.onprogress===null&&mprVideo.onsuspend===null&&mprOrder.length===5')! == 'true'
	assert !native_video.data.has_event_handler('progress') && !native_video.data.has_event_handler('suspend')
	assert video.get_attribute('onprogress') == none && video.get_attribute('onsuspend') == none
	media_progress_raw_owner_drain(document)
	assert runtime.evaluate_host('mprOrder.length===5&&mprSaved.length===5')! == 'true'
	// An absent removal leaves later IDL callbacks available for completion.
	assert runtime.evaluate_host('mprVideo.onprogress=mprProgressIDL;mprVideo.onsuspend=mprSuspendIDL;mprVideo.removeAttribute("onprogress");mprVideo.removeAttribute("onsuspend");__mediaProgressRawComplete();mprVideo.onprogress===mprProgressIDL&&mprVideo.onsuspend===mprSuspendIDL&&mprOrder.length===5')! == 'true'
	media_progress_raw_owner_drain(document)
	assert runtime.evaluate_host('mprOrder.join(",")==="replacement-progress,idl-progress,replacement-suspend,idl-progress,idl-suspend,idl-progress,idl-suspend"&&mprStates.join(",")==="2,2,1,1,1,1,1"&&mprChecks.length===8&&mprChecks.every(Boolean)&&mprSaved.length===7&&mprSaved.every(event=>event.isTrusted&&event.defaultPrevented)&&mprVideo.onprogress===mprProgressIDL&&mprVideo.onsuspend===mprSuspendIDL&&window.event===undefined')! == 'true'
	assert native_video.event_listener_list().len == 2
	assert media.event_count('progress') == 5 && media.event_count('suspend') == 4
	for index in 0 .. 7 {
		event := runtime.native_event(runtime.evaluate_host_value('mprSaved[${index}]')!)!
		media_progress_raw_owner_event(mut runtime, event, 'mprSaved[${index}]')!
	}
	app.poll_javascript_tasks()
	assert document.get_element_by_id('mpr-result')?.text_content()? == 'reentrant media progress painted'
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'reentrant media progress painted').len > 0
	assert app.js_messages == []
	media_progress_raw_owner_balance(runtime, document, 0)
}

fn test_media_raw_progress_scripting_gate_strict_original_exception_and_compound_suspend() {
	$if !darwin { return }
	mut app, mut document, mut runtime := media_progress_raw_owner_fixture(media_progress_raw_owner_markup, r'
globalThis.mprVideo=document.getElementById("mpr-video");globalThis.mprRuns=0;globalThis.mprSuspendRuns=0;globalThis.mprChecks=[];globalThis.mprSaved=[];globalThis.mprReason={original:true};globalThis.mprOrder=[];mprVideo.event={sentinel:true};document.event={sentinel:true};0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	media_progress_raw_owner_probe(mut runtime, document)!
	video := document.get_element_by_id('mpr-video')?
	native_video := unsafe { &dom.EventTarget(video) }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	media := html.html_media_element_for_dom_element(video) or { panic('Gated progress media owner missing') }
	media_progress_raw_owner_bridge(mut runtime, media, '__mediaProgressRawGatedStart', true)!
	media_progress_raw_owner_bridge(mut runtime, media, '__mediaProgressRawGatedComplete', false)!
	body := r'"use strict";mprRuns++;mprOrder.push("strict-progress");mprSaved.push(event);mprChecks.push(arguments.length===1&&event===arguments[0]&&this===mprVideo&&event.target===mprVideo&&event.currentTarget===mprVideo&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event&&this.networkState===1&&this.readyState===0&&this.currentTime===0&&this.paused&&__mediaProgressRawOwnerContext());try{void arguments.callee;mprChecks.push(false)}catch(error){mprChecks.push(error instanceof TypeError)}this.onprogress=null;globalThis.mprLiveName=onprogress;throw mprReason;'
	suspend_body := r'mprSuspendRuns++;mprOrder.push("raw-suspend");mprSaved.push(event);mprChecks.push(event.isTrusted&&this===mprVideo&&window.event===event&&this.networkState===1&&this.readyState===0&&this.currentTime===0&&this.paused&&__mediaProgressRawOwnerContext());return false;'
	assert runtime.evaluate_host('mprVideo.setAttribute("onprogress",${json2.encode(body)});mprVideo.setAttribute("onsuspend",${json2.encode(suspend_body)});mprVideo.paused')! == 'true'
	progress_slot := native_video.data.event_handler('progress') or { panic('Strict progress slot missing') }
	suspend_slot := native_video.data.event_handler('suspend') or { panic('Raw suspend slot missing') }
	mut owner := app.page_model
	owner.set_is_scripting_enabled(false)
	assert runtime.evaluate_host('__mediaProgressRawGatedStart()&&mprVideo.onprogress===null&&mprVideo.onsuspend===null&&mprRuns===0&&mprSuspendRuns===0')! == 'true'
	media_progress_raw_owner_drain(document)
	assert progress_slot.value.kind == .string && progress_slot.value.string_data == body
	assert suspend_slot.value.kind == .string && suspend_slot.value.string_data == suspend_body
	assert media.event_count('progress') == 2 && media.event_count('suspend') == 1 && media.network_state() == .idle
	assert runtime.evaluate_host('mprRuns===0&&mprSuspendRuns===0&&mprSaved.length===0&&mprOrder.length===0')! == 'true'
	media_progress_raw_owner_balance(runtime, document, 0)
	owner.set_is_scripting_enabled(true)
	assert runtime.evaluate_host(r'
globalThis.mprStrict=mprVideo.onprogress;globalThis.mprSuspend=mprVideo.onsuspend;
mprVideo.addEventListener("progress",function(event){mprOrder.push("later-progress");globalThis.mprLater=this===mprVideo&&event.currentTarget===mprVideo&&event.isTrusted&&!event.defaultPrevented&&window.event===event&&this.networkState===1;document.getElementById("mpr-result").textContent="later native progress listener"});typeof mprStrict==="function"&&mprStrict.name==="onprogress"&&mprStrict.length===1&&mprVideo.onprogress===mprStrict&&typeof mprSuspend==="function"&&mprSuspend.name==="onsuspend"&&mprVideo.onsuspend===mprSuspend&&mprRuns===0
')! == 'true'
	strict_callback := native_video.get_current_value_of_event_handler('progress') or { panic('Strict progress callback missing') }
	assert strict_callback.compiled_source_text_ == 'function onprogress(event) {\n${body}\n}'
	assert runtime.javascript_event_handler(native_video, 'progress')! == runtime.evaluate_host_value('mprStrict')!
	assert runtime.evaluate_host('__mediaProgressRawGatedComplete()&&mprOrder.length===0')! == 'true'
	// This single actual completion task runs the throwing raw progress,
	// its later listener, and the subsequent suspend without aborting dispatch.
	(media_progress_raw_owner_take_task(document) or { panic('Missing strict completion task') }).execute()
	assert media_progress_raw_owner_take_task(document) == none
	assert runtime.evaluate_host('mprOrder.join(",")==="strict-progress,later-progress,raw-suspend"&&mprRuns===1&&mprSuspendRuns===1&&mprLiveName===null&&mprVideo.onprogress===null&&mprVideo.onsuspend===mprSuspend&&mprLater&&mprChecks.length===3&&mprChecks.every(Boolean)&&mprSaved.length===2&&!mprSaved[0].defaultPrevented&&mprSaved[1].defaultPrevented&&window.event===undefined')! == 'true'
	assert !native_video.data.has_event_handler('progress') && native_video.data.has_event_handler('suspend')
	assert video.get_attribute_value('onprogress') == body && video.get_attribute_value('onsuspend') == suspend_body
	assert settings.realm().reported_exceptions.len == 1
	reported := settings.realm().reported_exceptions[0].value.as_webidl_value()!
	assert runtime.actual_webidl_value(reported)! == runtime.evaluate_host_value('mprReason')!
	assert media.event_count('progress') == 3 && media.event_count('suspend') == 2
	assert media.ready_state() == .have_nothing && media.current_time() == 0 && media.paused()
	for index in 0 .. 2 {
		event := runtime.native_event(runtime.evaluate_host_value('mprSaved[${index}]')!)!
		media_progress_raw_owner_event(mut runtime, event, 'mprSaved[${index}]')!
	}
	app.poll_javascript_tasks()
	assert document.get_element_by_id('mpr-result')?.text_content()? == 'later native progress listener'
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'later native progress listener').len > 0
	assert app.js_messages == []
	media_progress_raw_owner_balance(runtime, document, 1)
}

