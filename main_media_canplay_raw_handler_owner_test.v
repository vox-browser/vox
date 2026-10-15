module main

import browserjs
import dom
import html
import json2
import page
import time

const media_canplay_raw_owner_markup = '<!doctype html><style>
html,body{margin:0}#mcr-video{display:block;width:180px;height:60px}
#mcr-result{position:absolute;top:100px;left:0}
</style><form id="mcr-form"><video id="mcr-video"></video></form><div id="mcr-result">waiting</div>'

@[heap]
struct MediaCanplayRawOwnerObservation {
mut:
	events []&dom.Event
	targets []voidptr
}

fn media_canplay_raw_owner_fixture(markup string, source string) !(&BrowserApp, &dom.Document, &browserjs.Runtime) {
	mut owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{
		value: 'https://media-canplay-raw-owner.example.test/'
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

fn media_canplay_raw_owner_take_task(document &dom.Document) ?&html.Task {
	mut queue := html.main_thread_event_loop().task_queue()
	return queue.take_first_runnable_matching(fn [document] (task &html.Task) bool {
		owner := task.document() or { return false }
		return task.source() == .media_element && voidptr(owner) == voidptr(document)
	})
}

fn media_canplay_raw_owner_drain(document &dom.Document) {
	mut count := 0
	for {
		task := media_canplay_raw_owner_take_task(document) or { break }
		count++
		assert count < 100
		task.execute()
	}
}

fn media_canplay_raw_owner_checkpoint() {
	mut loop := html.main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
}

fn media_canplay_raw_owner_prepare(mut runtime browserjs.Runtime, document &dom.Document, element &dom.Element, alias string) !&html.HTMLMediaElement {
	mut media := html.html_media_element_for_dom_element(element) or { return error('Missing canplay media owner') }
	media.set_fetch_hook(fn (_ dom.URL, _ u64) !html.MediaResourceResponse {
		return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 20 }
	})
	assert runtime.evaluate_host('${alias}.src="/canplay.mp4";${alias}.load();${alias}.readyState===1')! == 'true'
	media_canplay_raw_owner_drain(document)
	media.set_show_poster(false)
	assert media.paused() && media.ready_state() == .have_metadata
	return media
}

fn media_canplay_raw_owner_probe(mut runtime browserjs.Runtime, document &dom.Document) ! {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	handle := voidptr(&runtime)
	actual_true := runtime.evaluate_host_value('true')!
	runtime.define_value_host_function('__mediaCanplayRawOwnerContext', fn [settings, handle, actual_true] (_ voidptr, args []voidptr) !voidptr {
		owner := unsafe { &browserjs.Runtime(handle) }
		assert args.len == 0
		assert settings.realm().script_execution_depth > 0 && settings.realm().callback_execution_depth > 0
		assert owner.libjs_vm().has_running_execution_context()
		assert voidptr(html.current_principal_settings_object()) == voidptr(settings)
		assert voidptr(html.incumbent_settings_object()) == voidptr(settings)
		return actual_true
	})!
}

fn media_canplay_raw_owner_observe(element &dom.Element, observation &MediaCanplayRawOwnerObservation) {
	handle := voidptr(observation)
	callback := &dom.CallbackType{
		handle_event: fn [handle] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut saved := unsafe { &MediaCanplayRawOwnerObservation(handle) }
			assert event.type_name() in ['canplay', 'canplaythrough']
			assert event.interface_ == .event && event.is_trusted()
			// The handler algorithm applies exact false to the canceled flag,
			// including native canplay events whose cancelable flag is false.
			assert !event.bubbles() && !event.cancelable() && event.default_prevented()
			saved.events << event
			saved.targets << voidptr(event.target() or { panic('Native canplay event needs its owner') })
			return dom.js_undefined()
		}
	}
	for name in ['canplay', 'canplaythrough'] {
		unsafe { &dom.EventTarget(element) }.add_event_listener_without_options(name, dom.IDLEventListener.create(callback))
	}
}

fn media_canplay_raw_owner_event(mut runtime browserjs.Runtime, event &dom.Event, expression string) ! {
	wrapper := runtime.evaluate_host_value(expression)!
	assert voidptr(runtime.native_event(wrapper)!) == voidptr(event)
	assert runtime.javascript_event(event)! == wrapper
	assert event.is_trusted() && event.current_target() == none && event.event_phase() == 0
	assert runtime.evaluate_host('${expression}.currentTarget===null&&${expression}.eventPhase===Event.NONE&&window.event===undefined')! == 'true'
}

fn media_canplay_raw_owner_balance(runtime &browserjs.Runtime, document &dom.Document, exceptions int) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == exceptions
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_media_raw_canplay_parsed_created_owner_scopes_trusted_events_and_play_promise_order() {
	$if !darwin { return }
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	body := r'mcrRuns++;mcrOrder.push(this.id+":"+event.type);mcrScopes.push(scopeKey);delete this.scopeKey;mcrScopes.push(scopeKey);delete document.scopeKey;mcrScopes.push(scopeKey);document.scopeKey="document";this.scopeKey=this.id==="mcr-video"?"parsed element":"created element";mcrSaved.push(event);mcrChecks.push(arguments.length===1&&event===arguments[0]&&(this===mcrVideo||this===mcrAudio)&&event.target===this&&event.currentTarget===this&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event&&document===mcrDocument&&getElementById("mcr-result")===mcrResult&&mcrValues.length===((this===mcrAudio?1:0)+(event.type==="canplaythrough"?1:0))&&__mediaCanplayRawOwnerContext());getElementById("mcr-result").textContent="raw media canplay painted";this.style.color="rgb(0,128,0)";return false;'
	attribute_body := body.replace('"', '&quot;')
	markup := media_canplay_raw_owner_markup.replace('<video id="mcr-video">',
		'<video id="mcr-video" oncanplay="${attribute_body}" oncanplaythrough="${attribute_body}">')
	mut app, mut document, mut runtime := media_canplay_raw_owner_fixture(markup, r'
globalThis.mcrVideo=document.getElementById("mcr-video");globalThis.mcrDocument=document;globalThis.mcrResult=document.getElementById("mcr-result");globalThis.mcrForm=document.getElementById("mcr-form");
globalThis.mcrRuns=0;globalThis.mcrOrder=[];globalThis.mcrScopes=[];globalThis.mcrSaved=[];globalThis.mcrChecks=[];globalThis.mcrReasons=[];globalThis.mcrValues=[];globalThis.scopeKey="global";
document.scopeKey="document";mcrForm.scopeKey="nearest form";mcrVideo.scopeKey="parsed element";mcrVideo.event={sentinel:true};document.event={sentinel:true};
globalThis.mcrAudio=document.createElement("audio");mcrAudio.id="mcr-audio";mcrAudio.setAttribute("oncanplay",mcrVideo.getAttribute("oncanplay"));mcrAudio.setAttribute("oncanplaythrough",mcrVideo.getAttribute("oncanplaythrough"));document.body.appendChild(mcrAudio);mcrAudio.scopeKey="created element";void mcrAudio.paused;
for(var mcrElement of [mcrVideo,mcrAudio])mcrElement.addEventListener("playing",function(event){mcrOrder.push(this.id+":playing");mcrChecks.push(this===event.target&&event.isTrusted&&!event.defaultPrevented&&mcrValues.length===(this===mcrAudio?1:0))});0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	media_canplay_raw_owner_probe(mut runtime, document)!
	video := document.get_element_by_id('mcr-video')?
	audio := document.get_element_by_id('mcr-audio')?
	native_video := unsafe { &dom.EventTarget(video) }
	native_audio := unsafe { &dom.EventTarget(audio) }
	for target in [native_video, native_audio] {
		for name in ['canplay', 'canplaythrough'] {
			slot := target.data.event_handler(name) or { panic('Raw canplay slot missing') }
			assert slot.value.kind == .string && slot.value.string_data == body
		}
	}
	assert runtime.evaluate_host(r'
globalThis.mcrVideoCanplay=mcrVideo.oncanplay;globalThis.mcrVideoThrough=mcrVideo.oncanplaythrough;globalThis.mcrAudioCanplay=mcrAudio.oncanplay;globalThis.mcrAudioThrough=mcrAudio.oncanplaythrough;
[mcrVideoCanplay,mcrVideoThrough,mcrAudioCanplay,mcrAudioThrough].every(value=>typeof value==="function"&&value.length===1)&&mcrVideoCanplay.name==="oncanplay"&&mcrAudioCanplay.name==="oncanplay"&&mcrVideoThrough.name==="oncanplaythrough"&&mcrAudioThrough.name==="oncanplaythrough"&&new Set([mcrVideoCanplay,mcrVideoThrough,mcrAudioCanplay,mcrAudioThrough]).size===4&&mcrVideo.oncanplay===mcrVideoCanplay&&mcrVideo.oncanplaythrough===mcrVideoThrough&&mcrAudio.oncanplay===mcrAudioCanplay&&mcrAudio.oncanplaythrough===mcrAudioThrough&&!Object.hasOwn(mcrVideo,"oncanplay")&&!Object.hasOwn(mcrAudio,"oncanplaythrough")&&mcrRuns===0
')! == 'true'
	for target in [native_video, native_audio] {
		for name in ['canplay', 'canplaythrough'] {
			callback := target.get_current_value_of_event_handler(name) or { panic('Cached canplay callback missing') }
			assert callback.compiled_source_text_ == 'function on${name}(event) {\n${body}\n}'
			alias := if voidptr(target) == voidptr(native_video) { 'mcrVideo' } else { 'mcrAudio' }
			assert runtime.javascript_event_handler(target, name)! == runtime.evaluate_host_value('${alias}.on${name}')!
		}
	}
	mut video_media := media_canplay_raw_owner_prepare(mut runtime, document, video, 'mcrVideo')!
	mut audio_media := media_canplay_raw_owner_prepare(mut runtime, document, audio, 'mcrAudio')!
	observation := &MediaCanplayRawOwnerObservation{}
	media_canplay_raw_owner_observe(video, observation)
	media_canplay_raw_owner_observe(audio, observation)
	assert runtime.evaluate_host(r'
globalThis.mcrVideoRequest=mcrVideo.play();globalThis.mcrAudioRequest=mcrAudio.play();
mcrVideoRequest.then(value=>{mcrChecks.push(value===undefined);mcrValues.push("video");mcrOrder.push("mcr-video:fulfilled")},reason=>mcrReasons.push(reason));mcrAudioRequest.then(value=>{mcrChecks.push(value===undefined);mcrValues.push("audio");mcrOrder.push("mcr-audio:fulfilled")},reason=>mcrReasons.push(reason));
mcrVideoRequest instanceof Promise&&mcrAudioRequest instanceof Promise&&mcrVideoRequest!==mcrAudioRequest&&!mcrVideo.paused&&!mcrAudio.paused&&mcrRuns===0
')! == 'true'
	video_request := video_media.play()
	audio_request := audio_media.play()
	media_canplay_raw_owner_drain(document)
	media_canplay_raw_owner_checkpoint()
	assert video_request.state() == .pending && audio_request.state() == .pending
	assert runtime.evaluate_host('mcrRuns===0&&mcrOrder.length===0&&mcrValues.length===0')! == 'true'
	// Pinned metadata-to-enough-data steps queue loadeddata, canplay, playing,
	// then canplaythrough. Only the playing task settles its captured batch.
	video_media.set_ready_state(.have_enough_data)
	for index in 0 .. 4 {
		if index < 3 {
			assert video_request.state() == .pending
		} else {
			assert video_request.state() == .fulfilled
		}
		(media_canplay_raw_owner_take_task(document) or { panic('Missing video canplay task') }).execute()
		media_canplay_raw_owner_checkpoint()
		assert audio_request.state() == .pending
		if index == 0 {
			assert runtime.evaluate_host('mcrRuns===0&&mcrOrder.length===0&&mcrValues.length===0')! == 'true'
		} else if index == 1 {
			assert video_request.state() == .pending
			assert runtime.evaluate_host('mcrRuns===1&&mcrOrder.join(",")==="mcr-video:canplay"&&mcrValues.length===0')! == 'true'
		} else if index == 2 {
			assert video_request.state() == .fulfilled
			assert runtime.evaluate_host('mcrRuns===1&&mcrOrder.join(",")==="mcr-video:canplay,mcr-video:playing,mcr-video:fulfilled"&&mcrValues.join(",")==="video"')! == 'true'
		}
	}
	assert video_request.state() == .fulfilled
	assert runtime.evaluate_host('mcrRuns===2&&mcrOrder.join(",")==="mcr-video:canplay,mcr-video:playing,mcr-video:fulfilled,mcr-video:canplaythrough"')! == 'true'
	audio_media.set_ready_state(.have_enough_data)
	for index in 0 .. 4 {
		if index < 3 {
			assert audio_request.state() == .pending
		} else {
			assert audio_request.state() == .fulfilled
		}
		(media_canplay_raw_owner_take_task(document) or { panic('Missing audio canplay task') }).execute()
		media_canplay_raw_owner_checkpoint()
		if index < 2 {
			assert audio_request.state() == .pending
			assert runtime.evaluate_host('mcrValues.join(",")==="video"')! == 'true'
		}
	}
	assert audio_request.state() == .fulfilled
	assert runtime.evaluate_host(r'mcrRuns===4&&mcrOrder.join(",")==="mcr-video:canplay,mcr-video:playing,mcr-video:fulfilled,mcr-video:canplaythrough,mcr-audio:canplay,mcr-audio:playing,mcr-audio:fulfilled,mcr-audio:canplaythrough"&&mcrScopes.join(",")==="parsed element,document,global,parsed element,document,global,created element,document,global,created element,document,global"&&mcrChecks.length===8&&mcrChecks.every(Boolean)&&mcrSaved.every(event=>event.defaultPrevented)&&mcrValues.join(",")==="video,audio"&&mcrReasons.length===0&&mcrForm.scopeKey==="nearest form"&&mcrVideo.oncanplay===mcrVideoCanplay&&mcrVideo.oncanplaythrough===mcrVideoThrough&&mcrAudio.oncanplay===mcrAudioCanplay&&mcrAudio.oncanplaythrough===mcrAudioThrough&&window.event===undefined')! == 'true'
	assert observation.events.len == 4
	assert observation.targets == [voidptr(video), voidptr(video), voidptr(audio), voidptr(audio)]
	for index, event in observation.events {
		media_canplay_raw_owner_event(mut runtime, event, 'mcrSaved[${index}]')!
	}
	assert video_media.event_count('canplay') == 1 && video_media.event_count('canplaythrough') == 1
	assert audio_media.event_count('canplay') == 1 && audio_media.event_count('canplaythrough') == 1
	app.poll_javascript_tasks()
	assert document.get_element_by_id('mcr-result')?.text_content()? == 'raw media canplay painted'
	assert video.get_attribute_value('style').contains('color') && audio.get_attribute_value('style').contains('color')
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'raw media canplay painted').len > 0
	assert app.js_messages == []
	media_canplay_raw_owner_balance(runtime, document, 0)
}

fn test_media_raw_canplay_live_equal_attribute_idl_removal_queued_replacement_and_reentrant_pause() {
	$if !darwin { return }
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	body := r'mcrOrder.push("raw-"+event.type);mcrSaved.push(event);return false;'
	attribute_body := body.replace('"', '&quot;')
	markup := media_canplay_raw_owner_markup.replace('<video id="mcr-video">',
		'<video id="mcr-video" oncanplay="${attribute_body}" oncanplaythrough="${attribute_body}">')
	mut app, mut document, mut runtime := media_canplay_raw_owner_fixture(markup, r'
globalThis.mcrVideo=document.getElementById("mcr-video");globalThis.mcrOrder=[];globalThis.mcrSaved=[];globalThis.mcrReasons=[];globalThis.mcrChecks=[];globalThis.mcrValues=[];globalThis.mcrSource=mcrVideo.getAttribute("oncanplay");globalThis.mcrFirstCanplay=mcrVideo.oncanplay;globalThis.mcrFirstThrough=mcrVideo.oncanplaythrough;
mcrVideo.addEventListener("playing",function(event){mcrOrder.push("playing");mcrChecks.push(this===mcrVideo&&event.isTrusted&&!event.defaultPrevented&&mcrValues.length===0)});
mcrVideo.addEventListener("pause",function(event){mcrOrder.push("pause");mcrChecks.push(this===mcrVideo&&event.isTrusted&&mcrVideo.paused&&mcrValues.length===1)});
globalThis.mcrCanplayIDL=function(event){mcrOrder.push("idl-canplay");mcrSaved.push(event);mcrChecks.push(window.event===event&&this===mcrVideo&&event.isTrusted&&!event.defaultPrevented&&mcrValues.length===0);return false};
globalThis.mcrThroughIDL=function(event){mcrOrder.push("idl-through");mcrSaved.push(event);mcrChecks.push(window.event===event&&this===mcrVideo&&event.isTrusted&&!event.defaultPrevented&&mcrValues.length===1);return false};0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	video := document.get_element_by_id('mcr-video')?
	native_video := unsafe { &dom.EventTarget(video) }
	mut media := media_canplay_raw_owner_prepare(mut runtime, document, video, 'mcrVideo')!
	canplay_slot := native_video.data.event_handler('canplay') or { panic('Canplay slot missing') }
	through_slot := native_video.data.event_handler('canplaythrough') or { panic('Through slot missing') }
	canplay_listener := canplay_slot.listener or { panic('Canplay listener missing') }
	through_listener := through_slot.listener or { panic('Through listener missing') }
	first_canplay := native_video.get_current_value_of_event_handler('canplay') or { panic('First canplay callback missing') }
	first_through := native_video.get_current_value_of_event_handler('canplaythrough') or { panic('First through callback missing') }
	assert runtime.evaluate_host(r'
mcrVideo.oncanplay=mcrCanplayIDL;mcrVideo.setAttribute("oncanplay",mcrSource);globalThis.mcrSecondCanplay=mcrVideo.oncanplay;
mcrVideo.oncanplaythrough=mcrThroughIDL;mcrVideo.setAttribute("oncanplaythrough",mcrSource);globalThis.mcrSecondThrough=mcrVideo.oncanplaythrough;
globalThis.mcrRequest=mcrVideo.play();mcrRequest.then(value=>{mcrChecks.push(value===undefined);mcrValues.push(value);mcrOrder.push("fulfilled")},reason=>mcrReasons.push(reason));
typeof mcrSecondCanplay==="function"&&mcrSecondCanplay!==mcrFirstCanplay&&mcrSecondCanplay!==mcrCanplayIDL&&mcrSecondCanplay.name==="oncanplay"&&mcrSecondCanplay.length===1&&typeof mcrSecondThrough==="function"&&mcrSecondThrough!==mcrFirstThrough&&mcrSecondThrough!==mcrThroughIDL&&mcrSecondThrough.name==="oncanplaythrough"&&mcrSecondThrough.length===1&&mcrVideo.oncanplay===mcrSecondCanplay&&mcrVideo.oncanplaythrough===mcrSecondThrough&&mcrOrder.length===0
')! == 'true'
	assert voidptr(native_video.data.event_handler('canplay') or { panic('Replaced canplay slot missing') }) == voidptr(canplay_slot)
	assert voidptr(native_video.data.event_handler('canplaythrough') or { panic('Replaced through slot missing') }) == voidptr(through_slot)
	assert voidptr(canplay_slot.listener or { panic('Replaced canplay listener missing') }) == voidptr(canplay_listener)
	assert voidptr(through_slot.listener or { panic('Replaced through listener missing') }) == voidptr(through_listener)
	second_canplay := native_video.get_current_value_of_event_handler('canplay') or { panic('Second canplay callback missing') }
	second_through := native_video.get_current_value_of_event_handler('canplaythrough') or { panic('Second through callback missing') }
	assert voidptr(second_canplay) != voidptr(first_canplay) && second_canplay.compiled_source_text_ == first_canplay.compiled_source_text_
	assert voidptr(second_through) != voidptr(first_through) && second_through.compiled_source_text_ == first_through.compiled_source_text_
	request := media.play()
	media_canplay_raw_owner_drain(document)
	media_canplay_raw_owner_checkpoint()
	assert request.state() == .pending
	assert runtime.evaluate_host('mcrOrder.length===0&&mcrValues.length===0&&mcrReasons.length===0')! == 'true'
	media.set_ready_state(.have_enough_data)
	assert runtime.evaluate_host(r'
mcrVideo.setAttribute("oncanplay","mcrOrder.push(\"reentrant-canplay\");mcrSaved.push(event);mcrChecks.push(!this.paused&&mcrValues.length===0);this.pause();this.oncanplay=mcrCanplayIDL;return false;");
mcrVideo.setAttribute("oncanplaythrough","mcrOrder.push(\"replacement-through\");mcrSaved.push(event);mcrChecks.push(this.paused&&mcrValues.length===1);document.getElementById(\"mcr-result\").textContent=\"reentrant canplay painted\";return false;");mcrValues.length===0&&!mcrVideo.paused
')! == 'true'
	assert voidptr(native_video.data.event_handler('canplay') or { panic('Queued replacement slot missing') }) == voidptr(canplay_slot)
	assert voidptr(native_video.data.event_handler('canplaythrough') or { panic('Queued replacement through slot missing') }) == voidptr(through_slot)
	// The playing task already owns the pending batch. Pausing from canplay
	// therefore cannot reject that batch or suppress the queued playing event.
	(media_canplay_raw_owner_take_task(document) or { panic('Missing first-data task') }).execute()
	assert request.state() == .pending && !media.paused()
	(media_canplay_raw_owner_take_task(document) or { panic('Missing reentrant canplay task') }).execute()
	media_canplay_raw_owner_checkpoint()
	assert request.state() == .pending && media.paused()
	assert runtime.evaluate_host('mcrOrder.join(",")==="reentrant-canplay"&&mcrValues.length===0&&mcrVideo.oncanplay===mcrCanplayIDL&&mcrSaved[0].isTrusted&&mcrSaved[0].defaultPrevented')! == 'true'
	(media_canplay_raw_owner_take_task(document) or { panic('Missing captured-batch playing task') }).execute()
	assert request.state() == .fulfilled
	media_canplay_raw_owner_checkpoint()
	assert runtime.evaluate_host('mcrOrder.join(",")==="reentrant-canplay,playing,fulfilled"&&mcrValues.length===1&&mcrValues[0]===undefined&&mcrReasons.length===0')! == 'true'
	(media_canplay_raw_owner_take_task(document) or { panic('Missing replaced through task') }).execute()
	assert runtime.evaluate_host('mcrOrder.join(",")==="reentrant-canplay,playing,fulfilled,replacement-through"&&mcrChecks.every(Boolean)&&mcrSaved[1].isTrusted&&mcrSaved[1].defaultPrevented')! == 'true'
	media_canplay_raw_owner_drain(document)
	assert runtime.evaluate_host('mcrOrder.join(",")==="reentrant-canplay,playing,fulfilled,replacement-through,pause"&&mcrChecks.every(Boolean)')! == 'true'
	assert runtime.evaluate_host(r'
mcrVideo.oncanplay=mcrCanplayIDL;mcrVideo.oncanplaythrough=mcrThroughIDL;mcrVideo.removeAttribute("oncanplay");mcrVideo.removeAttribute("oncanplaythrough");mcrVideo.oncanplay===null&&mcrVideo.oncanplaythrough===null
')! == 'true'
	assert !native_video.data.has_event_handler('canplay') && !native_video.data.has_event_handler('canplaythrough')
	assert video.get_attribute('oncanplay') == none && video.get_attribute('oncanplaythrough') == none
	assert runtime.evaluate_host(r'
mcrVideo.oncanplay=mcrCanplayIDL;mcrVideo.oncanplaythrough=mcrThroughIDL;mcrVideo.removeAttribute("oncanplay");mcrVideo.removeAttribute("oncanplaythrough");mcrOrder=[];mcrValues=[];mcrVideo.oncanplay===mcrCanplayIDL&&mcrVideo.oncanplaythrough===mcrThroughIDL
')! == 'true'
	media.set_ready_state(.have_current_data)
	assert runtime.evaluate_host(r'globalThis.mcrSecondRequest=mcrVideo.play();mcrSecondRequest.then(value=>{mcrChecks.push(value===undefined);mcrValues.push(value);mcrOrder.push("fulfilled")},reason=>mcrReasons.push(reason));mcrOrder.length===0')! == 'true'
	media_canplay_raw_owner_drain(document)
	media_canplay_raw_owner_checkpoint()
	assert runtime.evaluate_host('mcrOrder.length===0&&mcrValues.length===0')! == 'true'
	media.set_ready_state(.have_enough_data)
	for _ in 0 .. 3 {
		(media_canplay_raw_owner_take_task(document) or { panic('Missing later IDL canplay task') }).execute()
		media_canplay_raw_owner_checkpoint()
	}
	assert runtime.evaluate_host('mcrOrder.join(",")==="idl-canplay,playing,fulfilled,idl-through"&&mcrValues.length===1&&mcrValues[0]===undefined&&mcrReasons.length===0&&mcrChecks.every(Boolean)&&mcrSaved.length===4&&mcrSaved.every(event=>event.isTrusted&&event.defaultPrevented)&&window.event===undefined')! == 'true'
	assert native_video.event_listener_list().len == 4
	assert media.event_count('canplay') == 2 && media.event_count('canplaythrough') == 2 && media.event_count('playing') == 2 && media.event_count('pause') == 1
	for index in 0 .. 4 {
		event := runtime.native_event(runtime.evaluate_host_value('mcrSaved[${index}]')!)!
		media_canplay_raw_owner_event(mut runtime, event, 'mcrSaved[${index}]')!
	}
	app.poll_javascript_tasks()
	assert document.get_element_by_id('mcr-result')?.text_content()? == 'reentrant canplay painted'
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'reentrant canplay painted').len > 0
	assert app.js_messages == []
	media_canplay_raw_owner_balance(runtime, document, 0)
}

fn test_media_raw_canplay_scripting_gate_strict_original_exception_and_later_owner_listener() {
	$if !darwin { return }
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	mut app, mut document, mut runtime := media_canplay_raw_owner_fixture(media_canplay_raw_owner_markup, r'
globalThis.mcrVideo=document.getElementById("mcr-video");globalThis.mcrRuns=0;globalThis.mcrThroughRuns=0;globalThis.mcrChecks=[];globalThis.mcrSaved=[];globalThis.mcrReason={original:true};globalThis.mcrReasons=[];globalThis.mcrValues=[];globalThis.mcrOrder=[];mcrVideo.event={sentinel:true};document.event={sentinel:true};0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	media_canplay_raw_owner_probe(mut runtime, document)!
	video := document.get_element_by_id('mcr-video')?
	native_video := unsafe { &dom.EventTarget(video) }
	mut media := media_canplay_raw_owner_prepare(mut runtime, document, video, 'mcrVideo')!
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	body := r'"use strict";mcrRuns++;mcrOrder.push("strict-canplay");mcrSaved.push(event);mcrChecks.push(arguments.length===1&&event===arguments[0]&&this===mcrVideo&&event.target===mcrVideo&&event.currentTarget===mcrVideo&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event&&mcrValues.length===0&&__mediaCanplayRawOwnerContext());try{void arguments.callee;mcrChecks.push(false)}catch(error){mcrChecks.push(error instanceof TypeError)}this.oncanplay=null;globalThis.mcrLiveName=oncanplay;throw mcrReason;'
	through_body := r'mcrThroughRuns++;mcrOrder.push("raw-through");mcrSaved.push(event);mcrChecks.push(event.isTrusted&&this===mcrVideo&&window.event===event&&mcrValues.length===1&&__mediaCanplayRawOwnerContext());return false;'
	// Synchronize raw attributes through the compact state before recording the
	// slots, so src's pending attribute snapshot cannot overwrite them later.
	assert runtime.evaluate_host('mcrVideo.setAttribute("oncanplay",${json2.encode(body)});mcrVideo.setAttribute("oncanplaythrough",${json2.encode(through_body)});mcrVideo.paused')! == 'true'
	canplay_slot := native_video.data.event_handler('canplay') or { panic('Strict canplay slot missing') }
	through_slot := native_video.data.event_handler('canplaythrough') or { panic('Raw through slot missing') }
	mut owner := app.page_model
	owner.set_is_scripting_enabled(false)
	assert runtime.evaluate_host(r'
mcrVideo.play().catch(reason=>mcrReasons.push(reason));mcrVideo.oncanplay===null&&mcrVideo.oncanplaythrough===null&&mcrRuns===0&&mcrThroughRuns===0
')! == 'true'
	media_canplay_raw_owner_drain(document)
	media.set_ready_state(.have_enough_data)
	media_canplay_raw_owner_drain(document)
	media_canplay_raw_owner_checkpoint()
	assert canplay_slot.value.kind == .string && canplay_slot.value.string_data == body
	assert through_slot.value.kind == .string && through_slot.value.string_data == through_body
	assert runtime.evaluate_host('mcrRuns===0&&mcrThroughRuns===0&&mcrSaved.length===0&&mcrOrder.length===0')! == 'true'
	media_canplay_raw_owner_balance(runtime, document, 0)
	owner.set_is_scripting_enabled(true)
	assert runtime.evaluate_host(r'
globalThis.mcrStrict=mcrVideo.oncanplay;globalThis.mcrThrough=mcrVideo.oncanplaythrough;
mcrVideo.addEventListener("canplay",function(event){mcrOrder.push("later-canplay");globalThis.mcrLater=this===mcrVideo&&event.currentTarget===mcrVideo&&event.isTrusted&&!event.defaultPrevented&&window.event===event&&mcrValues.length===0;document.getElementById("mcr-result").textContent="later media canplay listener"});mcrVideo.pause();typeof mcrStrict==="function"&&mcrStrict.name==="oncanplay"&&mcrStrict.length===1&&mcrVideo.oncanplay===mcrStrict&&typeof mcrThrough==="function"&&mcrThrough.name==="oncanplaythrough"&&mcrVideo.oncanplaythrough===mcrThrough&&mcrRuns===0
')! == 'true'
	media_canplay_raw_owner_drain(document)
	media.set_ready_state(.have_current_data)
	strict_callback := native_video.get_current_value_of_event_handler('canplay') or { panic('Strict canplay callback missing') }
	assert strict_callback.compiled_source_text_ == 'function oncanplay(event) {\n${body}\n}'
	assert runtime.javascript_event_handler(native_video, 'canplay')! == runtime.evaluate_host_value('mcrStrict')!
	assert runtime.evaluate_host(r'globalThis.mcrRequest=mcrVideo.play();mcrRequest.then(value=>{mcrChecks.push(value===undefined);mcrValues.push(value);mcrOrder.push("fulfilled")},reason=>mcrReasons.push(reason));mcrOrder.length===0')! == 'true'
	request := media.play()
	media_canplay_raw_owner_drain(document)
	media_canplay_raw_owner_checkpoint()
	assert request.state() == .pending
	media.set_ready_state(.have_enough_data)
	(media_canplay_raw_owner_take_task(document) or { panic('Missing strict canplay task') }).execute()
	media_canplay_raw_owner_checkpoint()
	assert request.state() == .pending
	assert runtime.evaluate_host('mcrOrder.join(",")==="strict-canplay,later-canplay"&&mcrRuns===1&&mcrThroughRuns===0&&mcrValues.length===0&&mcrLiveName===null&&mcrVideo.oncanplay===null&&mcrLater&&mcrChecks.every(Boolean)&&window.event===undefined')! == 'true'
	assert !native_video.data.has_event_handler('canplay') && native_video.data.has_event_handler('canplaythrough')
	assert video.get_attribute_value('oncanplay') == body && video.get_attribute_value('oncanplaythrough') == through_body
	assert settings.realm().reported_exceptions.len == 1
	reported := settings.realm().reported_exceptions[0].value.as_webidl_value()!
	assert runtime.actual_webidl_value(reported)! == runtime.evaluate_host_value('mcrReason')!
	(media_canplay_raw_owner_take_task(document) or { panic('Missing strict-case playing task') }).execute()
	assert request.state() == .fulfilled
	media_canplay_raw_owner_checkpoint()
	assert runtime.evaluate_host('mcrValues.length===1&&mcrValues[0]===undefined&&mcrOrder.join(",")==="strict-canplay,later-canplay,fulfilled"')! == 'true'
	(media_canplay_raw_owner_take_task(document) or { panic('Missing strict-case through task') }).execute()
	assert runtime.evaluate_host('mcrRuns===1&&mcrThroughRuns===1&&mcrChecks.length===4&&mcrChecks.every(Boolean)&&mcrVideo.oncanplaythrough===mcrThrough&&mcrSaved.length===2&&!mcrSaved[0].defaultPrevented&&mcrSaved[1].defaultPrevented&&mcrValues.length===1&&mcrReasons.length===0&&mcrOrder.join(",")==="strict-canplay,later-canplay,fulfilled,raw-through"&&window.event===undefined')! == 'true'
	for index in 0 .. 2 {
		event := runtime.native_event(runtime.evaluate_host_value('mcrSaved[${index}]')!)!
		media_canplay_raw_owner_event(mut runtime, event, 'mcrSaved[${index}]')!
	}
	app.poll_javascript_tasks()
	assert document.get_element_by_id('mcr-result')?.text_content()? == 'later media canplay listener'
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'later media canplay listener').len > 0
	assert app.js_messages == []
	media_canplay_raw_owner_balance(runtime, document, 1)
}

