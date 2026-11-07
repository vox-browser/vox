module main

import browserjs
import dom
import html
import json2
import page
import time

const media_readiness_raw_owner_markup = '<!doctype html><style>
html,body{margin:0}#mrr-video{display:block;width:180px;height:60px}
#mrr-result{position:absolute;top:100px;left:0}
</style><form id="mrr-form"><video id="mrr-video"></video></form><div id="mrr-result">waiting</div>'

@[heap]
struct MediaReadinessRawOwnerObservation {
mut:
	events []&dom.Event
	targets []voidptr
}

fn media_readiness_raw_owner_fixture(markup string, source string) !(&BrowserApp, &dom.Document, &browserjs.Runtime) {
	mut owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{
		value: 'https://media-readiness-raw-owner.example.test/'
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

fn media_readiness_raw_owner_take_task(document &dom.Document) ?&html.Task {
	mut queue := html.main_thread_event_loop().task_queue()
	return queue.take_first_runnable_matching(fn [document] (task &html.Task) bool {
		owner := task.document() or { return false }
		return task.source() == .media_element && voidptr(owner) == voidptr(document)
	})
}

fn media_readiness_raw_owner_drain(document &dom.Document) {
	mut count := 0
	for {
		task := media_readiness_raw_owner_take_task(document) or { break }
		count++
		assert count < 100
		task.execute()
	}
}

fn media_readiness_raw_owner_checkpoint() {
	mut loop := html.main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
}

fn media_readiness_raw_owner_prepare(mut runtime browserjs.Runtime, document &dom.Document, element &dom.Element, alias string) !&html.HTMLMediaElement {
	mut media := html.html_media_element_for_dom_element(element) or { return error('Missing readiness media owner') }
	media.set_fetch_hook(fn (_ dom.URL, _ u64) !html.MediaResourceResponse {
		return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 20 }
	})
	assert runtime.evaluate_host('${alias}.src="/readiness.mp4";${alias}.load();${alias}.readyState===1')! == 'true'
	media_readiness_raw_owner_drain(document)
	media.set_show_poster(false)
	assert media.paused() && media.ready_state() == .have_metadata
	return media
}

fn media_readiness_raw_owner_probe(mut runtime browserjs.Runtime, document &dom.Document) ! {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	handle := voidptr(&runtime)
	actual_true := runtime.evaluate_host_value('true')!
	runtime.define_value_host_function('__mediaReadinessRawOwnerContext', fn [settings, handle, actual_true] (_ voidptr, args []voidptr) !voidptr {
		owner := unsafe { &browserjs.Runtime(handle) }
		assert args.len == 0
		assert settings.realm().script_execution_depth > 0 && settings.realm().callback_execution_depth > 0
		assert owner.libjs_vm().has_running_execution_context()
		assert voidptr(html.current_principal_settings_object()) == voidptr(settings)
		assert voidptr(html.incumbent_settings_object()) == voidptr(settings)
		return actual_true
	})!
}

fn media_readiness_raw_owner_observe(element &dom.Element, observation &MediaReadinessRawOwnerObservation) {
	handle := voidptr(observation)
	callback := &dom.CallbackType{
		handle_event: fn [handle] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut saved := unsafe { &MediaReadinessRawOwnerObservation(handle) }
			assert event.type_name() in ['playing', 'waiting']
			assert event.interface_ == .event && event.is_trusted()
			// The handler algorithm applies exact false to the canceled flag,
			// including native readiness events whose cancelable flag is false.
			assert !event.bubbles() && !event.cancelable() && event.default_prevented()
			saved.events << event
			saved.targets << voidptr(event.target() or { panic('Native readiness event needs its owner') })
			return dom.js_undefined()
		}
	}
	for name in ['playing', 'waiting'] {
		unsafe { &dom.EventTarget(element) }.add_event_listener_without_options(name, dom.IDLEventListener.create(callback))
	}
}

fn media_readiness_raw_owner_event(mut runtime browserjs.Runtime, event &dom.Event, expression string) ! {
	wrapper := runtime.evaluate_host_value(expression)!
	assert voidptr(runtime.native_event(wrapper)!) == voidptr(event)
	assert runtime.javascript_event(event)! == wrapper
	assert event.is_trusted() && event.current_target() == none && event.event_phase() == 0
	assert runtime.evaluate_host('${expression}.currentTarget===null&&${expression}.eventPhase===Event.NONE&&window.event===undefined')! == 'true'
}

fn media_readiness_raw_owner_balance(runtime &browserjs.Runtime, document &dom.Document, exceptions int) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == exceptions
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_media_raw_readiness_parsed_created_cache_scopes_actual_events_and_play_promise_batch() {
	$if !darwin { return }
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	body := r'mrrRuns++;mrrOrder.push(this.id+":"+event.type);mrrScopes.push(scopeKey);delete this.scopeKey;mrrScopes.push(scopeKey);delete document.scopeKey;mrrScopes.push(scopeKey);document.scopeKey="document";this.scopeKey=this.id==="mrr-video"?"parsed element":"created element";mrrSaved.push(event);mrrChecks.push(arguments.length===1&&event===arguments[0]&&(this===mrrVideo||this===mrrAudio)&&event.target===this&&event.currentTarget===this&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event&&document===mrrDocument&&getElementById("mrr-result")===mrrResult&&mrrValues.length===(this===mrrAudio&&event.type==="playing"?1:0)&&__mediaReadinessRawOwnerContext());getElementById("mrr-result").textContent="raw media readiness painted";this.style.color="rgb(0,128,0)";return false;'
	attribute_body := body.replace('"', '&quot;')
	markup := media_readiness_raw_owner_markup.replace('<video id="mrr-video">',
		'<video id="mrr-video" onplaying="${attribute_body}" onwaiting="${attribute_body}">')
	mut app, mut document, mut runtime := media_readiness_raw_owner_fixture(markup, r'
globalThis.mrrVideo=document.getElementById("mrr-video");globalThis.mrrDocument=document;globalThis.mrrResult=document.getElementById("mrr-result");globalThis.mrrForm=document.getElementById("mrr-form");
globalThis.mrrRuns=0;globalThis.mrrOrder=[];globalThis.mrrScopes=[];globalThis.mrrSaved=[];globalThis.mrrChecks=[];globalThis.mrrReasons=[];globalThis.mrrValues=[];globalThis.scopeKey="global";
document.scopeKey="document";mrrForm.scopeKey="nearest form";mrrVideo.scopeKey="parsed element";mrrVideo.event={sentinel:true};document.event={sentinel:true};
globalThis.mrrAudio=document.createElement("audio");mrrAudio.id="mrr-audio";mrrAudio.setAttribute("onplaying",mrrVideo.getAttribute("onplaying"));mrrAudio.setAttribute("onwaiting",mrrVideo.getAttribute("onwaiting"));document.body.appendChild(mrrAudio);mrrAudio.scopeKey="created element";void mrrAudio.paused;0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	media_readiness_raw_owner_probe(mut runtime, document)!
	video := document.get_element_by_id('mrr-video')?
	audio := document.get_element_by_id('mrr-audio')?
	native_video := unsafe { &dom.EventTarget(video) }
	native_audio := unsafe { &dom.EventTarget(audio) }
	for target in [native_video, native_audio] {
		for name in ['playing', 'waiting'] {
			slot := target.data.event_handler(name) or { panic('Raw readiness slot missing') }
			assert slot.value.kind == .string && slot.value.string_data == body
		}
	}
	assert runtime.evaluate_host(r'
globalThis.mrrVideoPlaying=mrrVideo.onplaying;globalThis.mrrVideoWaiting=mrrVideo.onwaiting;globalThis.mrrAudioPlaying=mrrAudio.onplaying;globalThis.mrrAudioWaiting=mrrAudio.onwaiting;
[mrrVideoPlaying,mrrVideoWaiting,mrrAudioPlaying,mrrAudioWaiting].every(value=>typeof value==="function"&&value.length===1)&&mrrVideoPlaying.name==="onplaying"&&mrrAudioPlaying.name==="onplaying"&&mrrVideoWaiting.name==="onwaiting"&&mrrAudioWaiting.name==="onwaiting"&&new Set([mrrVideoPlaying,mrrVideoWaiting,mrrAudioPlaying,mrrAudioWaiting]).size===4&&mrrVideo.onplaying===mrrVideoPlaying&&mrrVideo.onwaiting===mrrVideoWaiting&&mrrAudio.onplaying===mrrAudioPlaying&&mrrAudio.onwaiting===mrrAudioWaiting&&!Object.hasOwn(mrrVideo,"onplaying")&&!Object.hasOwn(mrrAudio,"onwaiting")&&mrrRuns===0
')! == 'true'
	for target in [native_video, native_audio] {
		for name in ['playing', 'waiting'] {
			callback := target.get_current_value_of_event_handler(name) or { panic('Cached readiness callback missing') }
			assert callback.compiled_source_text_ == 'function on${name}(event) {\n${body}\n}'
			alias := if voidptr(target) == voidptr(native_video) { 'mrrVideo' } else { 'mrrAudio' }
			assert runtime.javascript_event_handler(target, name)! == runtime.evaluate_host_value('${alias}.on${name}')!
		}
	}
	mut video_media := media_readiness_raw_owner_prepare(mut runtime, document, video, 'mrrVideo')!
	mut audio_media := media_readiness_raw_owner_prepare(mut runtime, document, audio, 'mrrAudio')!
	observation := &MediaReadinessRawOwnerObservation{}
	media_readiness_raw_owner_observe(video, observation)
	media_readiness_raw_owner_observe(audio, observation)
	assert runtime.evaluate_host(r'
globalThis.mrrVideoRequest=mrrVideo.play();globalThis.mrrAudioRequest=mrrAudio.play();
mrrVideoRequest.then(value=>{mrrChecks.push(value===undefined);mrrValues.push("video")},reason=>mrrReasons.push(reason));mrrAudioRequest.then(value=>{mrrChecks.push(value===undefined);mrrValues.push("audio")},reason=>mrrReasons.push(reason));
mrrVideoRequest instanceof Promise&&mrrAudioRequest instanceof Promise&&mrrVideoRequest!==mrrAudioRequest&&!mrrVideo.paused&&!mrrAudio.paused&&mrrRuns===0
')! == 'true'
	// Keep native convenience promises in the same actual pending batch as the
	// public JavaScript capabilities, without adding fabricated events or tasks.
	video_request := video_media.play()
	audio_request := audio_media.play()
	media_readiness_raw_owner_checkpoint()
	assert video_request.state() == .pending && audio_request.state() == .pending
	assert runtime.evaluate_host('mrrRuns===0&&mrrValues.length===0')! == 'true'
	media_readiness_raw_owner_drain(document)
	media_readiness_raw_owner_checkpoint()
	assert video_request.state() == .pending && audio_request.state() == .pending
	assert runtime.evaluate_host('mrrOrder.join(",")==="mrr-video:waiting,mrr-audio:waiting"&&mrrValues.length===0&&mrrReasons.length===0')! == 'true'
	video_media.set_ready_state(.have_future_data)
	for index in 0 .. 3 {
		assert video_request.state() == .pending && audio_request.state() == .pending
		(media_readiness_raw_owner_take_task(document) or { panic('Missing video readiness task') }).execute()
		if index < 2 {
			media_readiness_raw_owner_checkpoint()
			assert video_request.state() == .pending
			assert runtime.evaluate_host('mrrValues.length===0&&mrrRuns===2')! == 'true'
		}
	}
	assert video_request.state() == .fulfilled && audio_request.state() == .pending
	media_readiness_raw_owner_checkpoint()
	assert runtime.evaluate_host('mrrValues.join(",")==="video"&&mrrRuns===3')! == 'true'
	audio_media.set_ready_state(.have_future_data)
	for index in 0 .. 3 {
		assert audio_request.state() == .pending
		(media_readiness_raw_owner_take_task(document) or { panic('Missing audio readiness task') }).execute()
		if index < 2 {
			media_readiness_raw_owner_checkpoint()
			assert audio_request.state() == .pending
			assert runtime.evaluate_host('mrrValues.join(",")==="video"&&mrrRuns===3')! == 'true'
		}
	}
	assert audio_request.state() == .fulfilled
	media_readiness_raw_owner_checkpoint()
	assert runtime.evaluate_host(r'mrrRuns===4&&mrrOrder.join(",")==="mrr-video:waiting,mrr-audio:waiting,mrr-video:playing,mrr-audio:playing"&&mrrScopes.join(",")==="parsed element,document,global,created element,document,global,parsed element,document,global,created element,document,global"&&mrrChecks.length===6&&mrrChecks.every(Boolean)&&mrrSaved.every(event=>event.defaultPrevented)&&mrrValues.join(",")==="video,audio"&&mrrReasons.length===0&&mrrForm.scopeKey==="nearest form"&&mrrVideo.onplaying===mrrVideoPlaying&&mrrVideo.onwaiting===mrrVideoWaiting&&mrrAudio.onplaying===mrrAudioPlaying&&mrrAudio.onwaiting===mrrAudioWaiting&&window.event===undefined')! == 'true'
	assert observation.events.len == 4
	assert observation.targets == [voidptr(video), voidptr(audio), voidptr(video), voidptr(audio)]
	for index, event in observation.events {
		media_readiness_raw_owner_event(mut runtime, event, 'mrrSaved[${index}]')!
	}
	assert video_media.event_count('waiting') == 1 && video_media.event_count('playing') == 1
	assert audio_media.event_count('waiting') == 1 && audio_media.event_count('playing') == 1
	app.poll_javascript_tasks()
	assert document.get_element_by_id('mrr-result')?.text_content()? == 'raw media readiness painted'
	assert video.get_attribute_value('style').contains('color') && audio.get_attribute_value('style').contains('color')
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'raw media readiness painted').len > 0
	assert app.js_messages == []
	media_readiness_raw_owner_balance(runtime, document, 0)
}

fn test_media_raw_readiness_live_equal_attribute_idl_removal_queue_replacement_and_reentrant_pause() {
	$if !darwin { return }
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	body := r'mrrOrder.push("raw-"+event.type);mrrSaved.push(event);return false;'
	attribute_body := body.replace('"', '&quot;')
	markup := media_readiness_raw_owner_markup.replace('<video id="mrr-video">',
		'<video id="mrr-video" onplaying="${attribute_body}" onwaiting="${attribute_body}">')
	mut app, mut document, mut runtime := media_readiness_raw_owner_fixture(markup, r'
globalThis.mrrVideo=document.getElementById("mrr-video");globalThis.mrrOrder=[];globalThis.mrrSaved=[];globalThis.mrrReasons=[];globalThis.mrrChecks=[];globalThis.mrrValues=[];globalThis.mrrExpectedBefore=true;globalThis.mrrSource=mrrVideo.getAttribute("onwaiting");globalThis.mrrFirstWaiting=mrrVideo.onwaiting;globalThis.mrrFirstPlaying=mrrVideo.onplaying;
mrrVideo.addEventListener("waiting",function(event){mrrOrder.push("after-waiting");mrrChecks.push(this===mrrVideo&&event.target===mrrVideo&&event.currentTarget===mrrVideo&&event.isTrusted&&!event.bubbles&&!event.cancelable&&event.defaultPrevented===mrrExpectedBefore);document.getElementById("mrr-result").textContent=mrrOrder.join(",")});
mrrVideo.addEventListener("pause",function(event){mrrOrder.push("pause");mrrChecks.push(this===mrrVideo&&event.isTrusted&&mrrVideo.paused&&mrrValues.length===1)});
globalThis.mrrWaitingIDL=function(event){mrrOrder.push("idl-waiting");mrrSaved.push(event);mrrChecks.push(window.event===event&&this===mrrVideo&&!event.defaultPrevented);return false};
globalThis.mrrPlayingIDL=function(event){mrrOrder.push("idl-playing");mrrSaved.push(event);mrrChecks.push(window.event===event&&this===mrrVideo&&!event.defaultPrevented);return false};0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	video := document.get_element_by_id('mrr-video')?
	native_video := unsafe { &dom.EventTarget(video) }
	mut media := media_readiness_raw_owner_prepare(mut runtime, document, video, 'mrrVideo')!
	waiting_slot := native_video.data.event_handler('waiting') or { panic('Waiting slot missing') }
	playing_slot := native_video.data.event_handler('playing') or { panic('Playing slot missing') }
	waiting_listener := waiting_slot.listener or { panic('Waiting listener missing') }
	playing_listener := playing_slot.listener or { panic('Playing listener missing') }
	first_waiting := native_video.get_current_value_of_event_handler('waiting') or { panic('First waiting callback missing') }
	first_playing := native_video.get_current_value_of_event_handler('playing') or { panic('First playing callback missing') }
	assert runtime.evaluate_host(r'
mrrVideo.onwaiting=mrrWaitingIDL;mrrVideo.setAttribute("onwaiting",mrrSource);globalThis.mrrSecondWaiting=mrrVideo.onwaiting;
mrrVideo.onplaying=mrrPlayingIDL;mrrVideo.setAttribute("onplaying",mrrSource);globalThis.mrrSecondPlaying=mrrVideo.onplaying;
globalThis.mrrRequest=mrrVideo.play();mrrRequest.then(value=>{mrrChecks.push(value===undefined);mrrValues.push(value);mrrOrder.push("fulfilled")},reason=>mrrReasons.push(reason));
mrrVideo.setAttribute("onwaiting","mrrOrder.push(\"replacement-waiting\");mrrSaved.push(event);return false;");
typeof mrrSecondWaiting==="function"&&mrrSecondWaiting!==mrrFirstWaiting&&mrrSecondWaiting!==mrrWaitingIDL&&mrrSecondWaiting.name==="onwaiting"&&mrrSecondWaiting.length===1&&typeof mrrSecondPlaying==="function"&&mrrSecondPlaying!==mrrFirstPlaying&&mrrSecondPlaying!==mrrPlayingIDL&&mrrSecondPlaying.name==="onplaying"&&mrrSecondPlaying.length===1&&mrrVideo.onplaying===mrrSecondPlaying&&mrrOrder.length===0
')! == 'true'
	assert voidptr(native_video.data.event_handler('waiting') or { panic('Replaced waiting slot missing') }) == voidptr(waiting_slot)
	assert voidptr(native_video.data.event_handler('playing') or { panic('Replaced playing slot missing') }) == voidptr(playing_slot)
	assert voidptr(waiting_slot.listener or { panic('Replaced waiting listener missing') }) == voidptr(waiting_listener)
	assert voidptr(playing_slot.listener or { panic('Replaced playing listener missing') }) == voidptr(playing_listener)
	second_playing := native_video.get_current_value_of_event_handler('playing') or { panic('Second playing callback missing') }
	assert voidptr(second_playing) != voidptr(first_playing) && second_playing.compiled_source_text_ == first_playing.compiled_source_text_
	replacement_waiting := native_video.get_current_value_of_event_handler('waiting') or { panic('Replacement waiting callback missing') }
	assert voidptr(replacement_waiting) != voidptr(first_waiting) && replacement_waiting.compiled_source_text_ != first_waiting.compiled_source_text_
	request := media.play()
	media_readiness_raw_owner_drain(document)
	media_readiness_raw_owner_checkpoint()
	assert request.state() == .pending
	assert runtime.evaluate_host('mrrOrder.join(",")==="replacement-waiting,after-waiting"&&mrrValues.length===0&&mrrReasons.length===0&&mrrChecks.every(Boolean)')! == 'true'
	media.set_ready_state(.have_future_data)
	assert runtime.evaluate_host(r'
mrrVideo.setAttribute("onplaying","mrrOrder.push(\"reentrant-playing\");globalThis.mrrSelfPlayingEvent=event;this.pause();this.onplaying=mrrPlayingIDL;return false;");mrrValues.length===0&&!mrrVideo.paused
')! == 'true'
	for _ in 0 .. 3 {
		assert request.state() == .pending
		(media_readiness_raw_owner_take_task(document) or { panic('Missing reentrant playing task') }).execute()
	}
	assert request.state() == .fulfilled && media.paused()
	media_readiness_raw_owner_checkpoint()
	assert runtime.evaluate_host('mrrOrder.join(",")==="replacement-waiting,after-waiting,reentrant-playing,fulfilled"&&mrrSelfPlayingEvent.isTrusted&&mrrSelfPlayingEvent.defaultPrevented&&!mrrSelfPlayingEvent.cancelable&&mrrVideo.onplaying===mrrPlayingIDL&&mrrReasons.length===0')! == 'true'
	media_readiness_raw_owner_drain(document)
	assert runtime.evaluate_host('mrrOrder.join(",")==="replacement-waiting,after-waiting,reentrant-playing,fulfilled,pause"&&mrrChecks.every(Boolean)')! == 'true'
	assert runtime.evaluate_host(r'
mrrVideo.onwaiting=mrrWaitingIDL;mrrVideo.onplaying=mrrPlayingIDL;mrrVideo.removeAttribute("onwaiting");mrrVideo.removeAttribute("onplaying");mrrVideo.onwaiting===null&&mrrVideo.onplaying===null
')! == 'true'
	assert !native_video.data.has_event_handler('waiting') && !native_video.data.has_event_handler('playing')
	assert video.get_attribute('onwaiting') == none && video.get_attribute('onplaying') == none
	assert runtime.evaluate_host(r'
mrrVideo.onwaiting=mrrWaitingIDL;mrrVideo.onplaying=mrrPlayingIDL;mrrVideo.removeAttribute("onwaiting");mrrVideo.removeAttribute("onplaying");mrrOrder=[];mrrValues=[];mrrExpectedBefore=false;mrrVideo.onwaiting===mrrWaitingIDL&&mrrVideo.onplaying===mrrPlayingIDL
')! == 'true'
	media.set_ready_state(.have_current_data)
	assert runtime.evaluate_host(r'globalThis.mrrSecondRequest=mrrVideo.play();mrrSecondRequest.then(value=>{mrrValues.push(value);mrrOrder.push("fulfilled")},reason=>mrrReasons.push(reason));mrrOrder.length===0')! == 'true'
	media_readiness_raw_owner_drain(document)
	media_readiness_raw_owner_checkpoint()
	assert runtime.evaluate_host('mrrOrder.join(",")==="after-waiting,idl-waiting"&&mrrValues.length===0&&mrrChecks.every(Boolean)')! == 'true'
	media.set_ready_state(.have_future_data)
	media_readiness_raw_owner_drain(document)
	media_readiness_raw_owner_checkpoint()
	assert runtime.evaluate_host('mrrOrder.join(",")==="after-waiting,idl-waiting,idl-playing,fulfilled"&&mrrValues.length===1&&mrrValues[0]===undefined&&mrrReasons.length===0&&mrrChecks.every(Boolean)&&mrrSaved.every(event=>event.isTrusted&&event.defaultPrevented)&&window.event===undefined')! == 'true'
	assert native_video.event_listener_list().len == 4
	assert media.event_count('waiting') == 2 && media.event_count('playing') == 2 && media.event_count('pause') == 1
	for index in 0 .. 3 {
		event := runtime.native_event(runtime.evaluate_host_value('mrrSaved[${index}]')!)!
		media_readiness_raw_owner_event(mut runtime, event, 'mrrSaved[${index}]')!
	}
	playing_event := runtime.native_event(runtime.evaluate_host_value('mrrSelfPlayingEvent')!)!
	media_readiness_raw_owner_event(mut runtime, playing_event, 'mrrSelfPlayingEvent')!
	app.poll_javascript_tasks()
	assert document.get_element_by_id('mrr-result')?.text_content()? == 'after-waiting'
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'after-waiting').len > 0
	assert app.js_messages == []
	media_readiness_raw_owner_balance(runtime, document, 0)
}

fn test_media_raw_readiness_scripting_gate_strict_original_exception_and_later_owner_listener() {
	$if !darwin { return }
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	mut app, mut document, mut runtime := media_readiness_raw_owner_fixture(media_readiness_raw_owner_markup, r'
globalThis.mrrVideo=document.getElementById("mrr-video");globalThis.mrrRuns=0;globalThis.mrrPlayingRuns=0;globalThis.mrrChecks=[];globalThis.mrrSaved=[];globalThis.mrrReason={original:true};globalThis.mrrReasons=[];globalThis.mrrValues=[];globalThis.mrrOrder=[];mrrVideo.event={sentinel:true};document.event={sentinel:true};0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	media_readiness_raw_owner_probe(mut runtime, document)!
	mut video := document.get_element_by_id('mrr-video')?
	native_video := unsafe { &dom.EventTarget(video) }
	mut media := media_readiness_raw_owner_prepare(mut runtime, document, video, 'mrrVideo')!
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	body := r'"use strict";mrrRuns++;mrrOrder.push("strict-waiting");mrrSaved.push(event);mrrChecks.push(arguments.length===1&&event===arguments[0]&&this===mrrVideo&&event.target===mrrVideo&&event.currentTarget===mrrVideo&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event&&__mediaReadinessRawOwnerContext());try{void arguments.callee;mrrChecks.push(false)}catch(error){mrrChecks.push(error instanceof TypeError)}this.onwaiting=null;globalThis.mrrLiveName=onwaiting;throw mrrReason;'
	playing_body := r'mrrPlayingRuns++;mrrOrder.push("raw-playing");mrrSaved.push(event);mrrChecks.push(event.isTrusted&&this===mrrVideo&&window.event===event&&mrrValues.length===0&&__mediaReadinessRawOwnerContext());return false;'
	// Keep the raw attributes in the same compact state as the src mutation;
	// a later native getter replays that complete dirty attribute snapshot.
	assert runtime.evaluate_host('mrrVideo.setAttribute("onwaiting",${json2.encode(body)});mrrVideo.setAttribute("onplaying",${json2.encode(playing_body)});mrrVideo.paused')! == 'true'
	waiting_slot := native_video.data.event_handler('waiting') or { panic('Strict waiting slot missing') }
	playing_slot := native_video.data.event_handler('playing') or { panic('Raw playing slot missing') }
	mut owner := app.page_model
	owner.set_is_scripting_enabled(false)
	assert runtime.evaluate_host(r'
mrrVideo.play().catch(reason=>mrrReasons.push(reason));mrrVideo.onwaiting===null&&mrrVideo.onplaying===null&&mrrRuns===0&&mrrPlayingRuns===0
')! == 'true'
	media_readiness_raw_owner_drain(document)
	media.set_ready_state(.have_future_data)
	media_readiness_raw_owner_drain(document)
	media_readiness_raw_owner_checkpoint()
	assert waiting_slot.value.kind == .string && waiting_slot.value.string_data == body
	assert playing_slot.value.kind == .string && playing_slot.value.string_data == playing_body
	assert runtime.evaluate_host('mrrRuns===0&&mrrPlayingRuns===0&&mrrSaved.length===0&&mrrOrder.length===0')! == 'true'
	media_readiness_raw_owner_balance(runtime, document, 0)
	owner.set_is_scripting_enabled(true)
	assert runtime.evaluate_host(r'
globalThis.mrrStrict=mrrVideo.onwaiting;globalThis.mrrPlaying=mrrVideo.onplaying;
mrrVideo.addEventListener("waiting",function(event){mrrOrder.push("later-waiting");globalThis.mrrLater=this===mrrVideo&&event.currentTarget===mrrVideo&&!event.defaultPrevented&&window.event===event&&mrrValues.length===0;document.getElementById("mrr-result").textContent="later media readiness listener"});mrrVideo.pause();typeof mrrStrict==="function"&&mrrStrict.name==="onwaiting"&&mrrStrict.length===1&&mrrVideo.onwaiting===mrrStrict&&typeof mrrPlaying==="function"&&mrrPlaying.name==="onplaying"&&mrrVideo.onplaying===mrrPlaying&&mrrRuns===0
')! == 'true'
	media_readiness_raw_owner_drain(document)
	media.set_ready_state(.have_current_data)
	strict_callback := native_video.get_current_value_of_event_handler('waiting') or { panic('Strict waiting callback missing') }
	assert strict_callback.compiled_source_text_ == 'function onwaiting(event) {\n${body}\n}'
	assert runtime.javascript_event_handler(native_video, 'waiting')! == runtime.evaluate_host_value('mrrStrict')!
	assert runtime.evaluate_host(r'globalThis.mrrRequest=mrrVideo.play();mrrRequest.then(value=>{mrrChecks.push(value===undefined);mrrValues.push(value);mrrOrder.push("fulfilled")},reason=>mrrReasons.push(reason));mrrOrder.length===0')! == 'true'
	media_readiness_raw_owner_drain(document)
	media_readiness_raw_owner_checkpoint()
	assert runtime.evaluate_host('mrrOrder.join(",")==="strict-waiting,later-waiting"&&mrrRuns===1&&mrrPlayingRuns===0&&mrrValues.length===0&&mrrLiveName===null&&mrrVideo.onwaiting===null&&mrrLater&&mrrChecks.every(Boolean)&&window.event===undefined')! == 'true'
	assert !native_video.data.has_event_handler('waiting') && native_video.data.has_event_handler('playing')
	assert video.get_attribute_value('onwaiting') == body && video.get_attribute_value('onplaying') == playing_body
	assert settings.realm().reported_exceptions.len == 1
	reported := settings.realm().reported_exceptions[0].value.as_webidl_value()!
	assert runtime.actual_webidl_value(reported)! == runtime.evaluate_host_value('mrrReason')!
	media.set_ready_state(.have_future_data)
	media_readiness_raw_owner_drain(document)
	media_readiness_raw_owner_checkpoint()
	assert runtime.evaluate_host('mrrRuns===1&&mrrPlayingRuns===1&&mrrChecks.length===4&&mrrChecks.every(Boolean)&&mrrVideo.onplaying===mrrPlaying&&mrrSaved.length===2&&!mrrSaved[0].defaultPrevented&&mrrSaved[1].defaultPrevented&&mrrValues.length===1&&mrrValues[0]===undefined&&mrrReasons.length===0&&mrrOrder.join(",")==="strict-waiting,later-waiting,raw-playing,fulfilled"&&window.event===undefined')! == 'true'
	for index in 0 .. 2 {
		event := runtime.native_event(runtime.evaluate_host_value('mrrSaved[${index}]')!)!
		media_readiness_raw_owner_event(mut runtime, event, 'mrrSaved[${index}]')!
	}
	app.poll_javascript_tasks()
	assert document.get_element_by_id('mrr-result')?.text_content()? == 'later media readiness listener'
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'later media readiness listener').len > 0
	assert app.js_messages == []
	media_readiness_raw_owner_balance(runtime, document, 1)
}
