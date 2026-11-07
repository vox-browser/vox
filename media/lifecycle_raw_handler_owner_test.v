module main

import browserjs
import dom
import html
import page
import time

const media_lifecycle_raw_owner_markup = '<!doctype html><style>
html,body{margin:0}#ml-video{display:block;width:180px;height:60px}
#ml-result{position:absolute;top:100px;left:0}
</style><form id="ml-form"><video id="ml-video"></video></form><div id="ml-result">waiting</div>'

@[heap]
struct MediaLifecycleRawOwnerObservation {
mut:
	events []&dom.Event
	targets []voidptr
}

fn media_lifecycle_raw_owner_fixture(markup string, source string) !(&BrowserApp, &dom.Document, &browserjs.Runtime) {
	mut owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{
		value: 'https://media-lifecycle-raw-owner.example.test/'
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

fn media_lifecycle_raw_owner_drain(document &dom.Document) {
	mut queue := html.main_thread_event_loop().task_queue()
	mut count := 0
	for {
		task := queue.take_first_runnable_matching(fn [document] (task &html.Task) bool {
			owner := task.document() or { return false }
			return task.source() == .media_element && voidptr(owner) == voidptr(document)
		}) or { break }
		count++
		assert count < 100
		task.execute()
	}
}

fn media_lifecycle_raw_owner_checkpoint() {
	mut loop := html.main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
}

fn media_lifecycle_raw_owner_probe(mut runtime browserjs.Runtime, document &dom.Document) ! {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	handle := voidptr(&runtime)
	actual_true := runtime.evaluate_host_value('true')!
	runtime.define_value_host_function('__mediaLifecycleRawOwnerContext', fn [settings, handle, actual_true] (_ voidptr, args []voidptr) !voidptr {
		owner := unsafe { &browserjs.Runtime(handle) }
		assert args.len == 0
		assert settings.realm().script_execution_depth > 0 && settings.realm().callback_execution_depth > 0
		assert owner.libjs_vm().has_running_execution_context()
		assert voidptr(html.current_principal_settings_object()) == voidptr(settings)
		assert voidptr(html.incumbent_settings_object()) == voidptr(settings)
		return actual_true
	})!
}

fn media_lifecycle_raw_owner_observe(element &dom.Element, observation &MediaLifecycleRawOwnerObservation) {
	handle := voidptr(observation)
	callback := &dom.CallbackType{
		handle_event: fn [handle] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut saved := unsafe { &MediaLifecycleRawOwnerObservation(handle) }
			assert event.type_name() in ['play', 'pause']
			assert event.interface_ == .event && event.is_trusted()
			// Exact false sets the canceled flag directly in the event-handler
			// algorithm, including these non-cancelable lifecycle events.
			assert !event.bubbles() && !event.cancelable() && event.default_prevented()
			saved.events << event
			saved.targets << voidptr(event.target() or { panic('Native lifecycle event needs its owner') })
			return dom.js_undefined()
		}
	}
	for name in ['play', 'pause'] {
		unsafe { &dom.EventTarget(element) }.add_event_listener_without_options(name, dom.IDLEventListener.create(callback))
	}
}

fn media_lifecycle_raw_owner_event(mut runtime browserjs.Runtime, event &dom.Event, expression string) ! {
	wrapper := runtime.evaluate_host_value(expression)!
	assert voidptr(runtime.native_event(wrapper)!) == voidptr(event)
	assert runtime.javascript_event(event)! == wrapper
	assert event.is_trusted() && event.current_target() == none && event.event_phase() == 0
	assert runtime.evaluate_host('${expression}.currentTarget===null&&${expression}.eventPhase===Event.NONE&&window.event===undefined')! == 'true'
}

fn media_lifecycle_raw_owner_balance(runtime &browserjs.Runtime, document &dom.Document, exceptions int) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == exceptions
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_media_raw_play_pause_parsed_created_cache_actual_queued_events_scopes_and_paint() {
	$if !darwin { return }
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	body := r'mlRuns++;mlOrder.push(this.id+":"+event.type);mlScopes.push(scopeKey);delete this.scopeKey;mlScopes.push(scopeKey);delete document.scopeKey;mlScopes.push(scopeKey);document.scopeKey="document";this.scopeKey=this.id==="ml-video"?"parsed element":"created element";mlSaved.push(event);mlChecks.push(arguments.length===1&&event===arguments[0]&&(this===mlVideo||this===mlAudio)&&event.target===this&&event.currentTarget===this&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event&&document===mlDocument&&getElementById("ml-result")===mlResult&&__mediaLifecycleRawOwnerContext());getElementById("ml-result").textContent="raw media lifecycle painted";this.style.color="rgb(0,128,0)";return false;'
	attribute_body := body.replace('"', '&quot;')
	markup := media_lifecycle_raw_owner_markup.replace('<video id="ml-video">',
		'<video id="ml-video" onplay="${attribute_body}" onpause="${attribute_body}">')
	mut app, mut document, mut runtime := media_lifecycle_raw_owner_fixture(markup, r'
globalThis.mlVideo=document.getElementById("ml-video");globalThis.mlDocument=document;globalThis.mlResult=document.getElementById("ml-result");globalThis.mlForm=document.getElementById("ml-form");
globalThis.mlRuns=0;globalThis.mlOrder=[];globalThis.mlScopes=[];globalThis.mlSaved=[];globalThis.mlChecks=[];globalThis.mlReasons=[];globalThis.scopeKey="global";
document.scopeKey="document";mlForm.scopeKey="nearest form";mlVideo.scopeKey="parsed element";mlVideo.event={sentinel:true};document.event={sentinel:true};
globalThis.mlAudio=document.createElement("audio");mlAudio.id="ml-audio";mlAudio.setAttribute("onplay",mlVideo.getAttribute("onplay"));mlAudio.setAttribute("onpause",mlVideo.getAttribute("onpause"));document.body.appendChild(mlAudio);mlAudio.scopeKey="created element";void mlAudio.paused;0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	media_lifecycle_raw_owner_probe(mut runtime, document)!
	video := document.get_element_by_id('ml-video')?
	audio := document.get_element_by_id('ml-audio')?
	native_video := unsafe { &dom.EventTarget(video) }
	native_audio := unsafe { &dom.EventTarget(audio) }
	for target in [native_video, native_audio] {
		for name in ['play', 'pause'] {
			slot := target.data.event_handler(name) or { panic('Raw lifecycle slot missing') }
			assert slot.value.kind == .string && slot.value.string_data == body
		}
	}
	assert runtime.evaluate_host(r'
globalThis.mlVideoPlay=mlVideo.onplay;globalThis.mlVideoPause=mlVideo.onpause;globalThis.mlAudioPlay=mlAudio.onplay;globalThis.mlAudioPause=mlAudio.onpause;
[mlVideoPlay,mlVideoPause,mlAudioPlay,mlAudioPause].every(value=>typeof value==="function"&&value.length===1)&&mlVideoPlay.name==="onplay"&&mlAudioPlay.name==="onplay"&&mlVideoPause.name==="onpause"&&mlAudioPause.name==="onpause"&&new Set([mlVideoPlay,mlVideoPause,mlAudioPlay,mlAudioPause]).size===4&&mlVideo.onplay===mlVideoPlay&&mlVideo.onpause===mlVideoPause&&mlAudio.onplay===mlAudioPlay&&mlAudio.onpause===mlAudioPause&&!Object.hasOwn(mlVideo,"onplay")&&!Object.hasOwn(mlAudio,"onpause")&&mlRuns===0
')! == 'true'
	for target in [native_video, native_audio] {
		for name in ['play', 'pause'] {
			callback := target.get_current_value_of_event_handler(name) or { panic('Cached lifecycle callback missing') }
			assert callback.compiled_source_text_ == 'function on${name}(event) {\n${body}\n}'
			alias := if voidptr(target) == voidptr(native_video) { 'mlVideo' } else { 'mlAudio' }
			assert runtime.javascript_event_handler(target, name)! == runtime.evaluate_host_value('${alias}.on${name}')!
		}
	}
	observation := &MediaLifecycleRawOwnerObservation{}
	media_lifecycle_raw_owner_observe(video, observation)
	media_lifecycle_raw_owner_observe(audio, observation)
	assert runtime.evaluate_host(r'
for(const player of [mlVideo,mlAudio]){const request=player.play();mlChecks.push(request instanceof Promise&&!player.paused);player.pause();request.catch(reason=>{mlReasons.push(reason);mlOrder.push(player.id+":rejected")})}
mlRuns===0&&mlOrder.length===0&&mlVideo.paused&&mlAudio.paused
')! == 'true'
	media_lifecycle_raw_owner_checkpoint()
	assert runtime.evaluate_host('mlRuns===0&&mlReasons.length===0')! == 'true'
	media_lifecycle_raw_owner_drain(document)
	media_lifecycle_raw_owner_checkpoint()
	assert runtime.evaluate_host(r'mlRuns===4&&mlOrder.filter(value=>!value.endsWith(":rejected")).join(",")==="ml-video:play,ml-video:pause,ml-audio:play,ml-audio:pause"&&mlScopes.join(",")==="parsed element,document,global,parsed element,document,global,created element,document,global,created element,document,global"&&mlChecks.length===6&&mlChecks.every(Boolean)&&mlSaved.every(event=>event.defaultPrevented)&&mlReasons.length===2&&mlReasons.every(reason=>reason instanceof DOMException&&reason.name==="AbortError"&&reason.message==="Media playback was paused")&&mlForm.scopeKey==="nearest form"&&mlVideo.onplay===mlVideoPlay&&mlVideo.onpause===mlVideoPause&&mlAudio.onplay===mlAudioPlay&&mlAudio.onpause===mlAudioPause&&window.event===undefined')! == 'true'
	assert observation.events.len == 4
	assert observation.targets == [voidptr(video), voidptr(video), voidptr(audio), voidptr(audio)]
	for index, event in observation.events {
		media_lifecycle_raw_owner_event(mut runtime, event, 'mlSaved[${index}]')!
	}
	assert html.html_media_element_for_dom_element(video)?.event_count('play') == 1
	assert html.html_media_element_for_dom_element(video)?.event_count('pause') == 1
	assert html.html_media_element_for_dom_element(audio)?.event_count('play') == 1
	assert html.html_media_element_for_dom_element(audio)?.event_count('pause') == 1
	app.poll_javascript_tasks()
	assert document.get_element_by_id('ml-result')?.text_content()? == 'raw media lifecycle painted'
	assert video.get_attribute_value('style').contains('color') && audio.get_attribute_value('style').contains('color')
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'raw media lifecycle painted').len > 0
	assert app.js_messages == []
	media_lifecycle_raw_owner_balance(runtime, document, 0)
}

fn test_media_raw_play_pause_live_equal_attribute_idl_removal_queue_replacement_and_reentrant_pause() {
	$if !darwin { return }
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	body := r'mlOrder.push("raw-"+event.type);mlSaved.push(event);return false;'
	attribute_body := body.replace('"', '&quot;')
	markup := media_lifecycle_raw_owner_markup.replace('<video id="ml-video">',
		'<video id="ml-video" onplay="${attribute_body}" onpause="${attribute_body}">')
	mut app, mut document, mut runtime := media_lifecycle_raw_owner_fixture(markup, r'
globalThis.mlVideo=document.getElementById("ml-video");globalThis.mlOrder=[];globalThis.mlSaved=[];globalThis.mlReasons=[];globalThis.mlChecks=[];globalThis.mlExpectedBefore=true;globalThis.mlSource=mlVideo.getAttribute("onpause");globalThis.mlFirst=mlVideo.onpause;
mlVideo.addEventListener("pause",function(event){mlOrder.push("after");mlChecks.push(this===mlVideo&&event.target===mlVideo&&event.currentTarget===mlVideo&&event.isTrusted&&!event.cancelable&&event.defaultPrevented===mlExpectedBefore);document.getElementById("ml-result").textContent=mlOrder.join(",")});
globalThis.mlIDL=function(event){mlOrder.push("idl");mlSaved.push(event);mlChecks.push(window.event===event&&this===mlVideo&&!event.defaultPrevented);return false};0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	video := document.get_element_by_id('ml-video')?
	native_video := unsafe { &dom.EventTarget(video) }
	slot := native_video.data.event_handler('pause') or { panic('Pause slot missing') }
	listener := slot.listener or { panic('Pause listener missing') }
	first := native_video.get_current_value_of_event_handler('pause') or { panic('First raw pause callback missing') }
	assert runtime.evaluate_host(r'
mlVideo.onpause=mlIDL;mlVideo.setAttribute("onpause",mlSource);globalThis.mlSecond=mlVideo.onpause;
const request=mlVideo.play();mlVideo.pause();request.catch(reason=>{mlReasons.push(reason);mlOrder.push("rejected")});
mlVideo.setAttribute("onplay","mlOrder.push(\"replacement-play\");mlSaved.push(event);return false;");
typeof mlSecond==="function"&&mlSecond!==mlFirst&&mlSecond!==mlIDL&&mlSecond.name==="onpause"&&mlSecond.length===1&&mlVideo.onpause===mlSecond&&mlOrder.length===0
')! == 'true'
	assert voidptr(native_video.data.event_handler('pause') or { panic('Replaced pause slot missing') }) == voidptr(slot)
	assert voidptr(slot.listener or { panic('Replaced pause listener missing') }) == voidptr(listener)
	second := native_video.get_current_value_of_event_handler('pause') or { panic('Second raw pause callback missing') }
	assert voidptr(second) != voidptr(first) && second.compiled_source_text_ == first.compiled_source_text_
	media_lifecycle_raw_owner_drain(document)
	media_lifecycle_raw_owner_checkpoint()
	assert runtime.evaluate_host('mlOrder.join(",")==="replacement-play,raw-pause,after,rejected"&&mlReasons.length===1&&mlReasons[0].name==="AbortError"&&mlChecks.every(Boolean)&&mlSaved.every(event=>event.isTrusted&&event.defaultPrevented)')! == 'true'
	assert runtime.evaluate_host('mlVideo.onpause=mlIDL;mlVideo.removeAttribute("onpause");mlVideo.onpause===null')! == 'true'
	assert !native_video.data.has_event_handler('pause') && video.get_attribute('onpause') == none
	assert runtime.evaluate_host(r'
mlVideo.onpause=mlIDL;mlVideo.removeAttribute("onpause");mlOrder=[];mlExpectedBefore=false;
const secondRequest=mlVideo.play();mlVideo.pause();secondRequest.catch(reason=>{mlReasons.push(reason);mlOrder.push("rejected")});mlVideo.onpause===mlIDL
')! == 'true'
	media_lifecycle_raw_owner_drain(document)
	media_lifecycle_raw_owner_checkpoint()
	assert runtime.evaluate_host('mlOrder.join(",")==="replacement-play,after,idl,rejected"&&mlReasons.length===2&&mlChecks.every(Boolean)&&mlSaved.every(event=>event.defaultPrevented)&&mlVideo.onpause===mlIDL')! == 'true'
	// pause() from the actual play callback queues a later owner task. The raw
	// pause callback can replace itself without acquiring another listener.
	assert runtime.evaluate_host(r'
mlOrder=[];mlVideo.setAttribute("onplay","mlOrder.push(\"reentrant-play\");this.pause();");
mlVideo.setAttribute("onpause","mlOrder.push(\"self-pause\");globalThis.mlSelfPauseEvent=event;this.onpause=mlIDL;return false;");
mlVideo.play().catch(reason=>{mlReasons.push(reason);mlOrder.push("rejected")});mlOrder.length===0&&!mlVideo.paused
')! == 'true'
	media_lifecycle_raw_owner_drain(document)
	media_lifecycle_raw_owner_checkpoint()
	assert runtime.evaluate_host('mlOrder.join(",")==="reentrant-play,after,self-pause,rejected"&&mlVideo.paused&&mlVideo.onpause===mlIDL&&mlSelfPauseEvent.defaultPrevented&&!mlSelfPauseEvent.cancelable&&mlReasons.length===3&&mlReasons.every(reason=>reason instanceof DOMException&&reason.name==="AbortError")&&mlChecks.every(Boolean)&&window.event===undefined')! == 'true'
	assert native_video.event_listener_list().len == 3
	assert html.html_media_element_for_dom_element(video)?.event_count('play') == 3
	assert html.html_media_element_for_dom_element(video)?.event_count('pause') == 3
	app.poll_javascript_tasks()
	assert document.get_element_by_id('ml-result')?.text_content()? == 'reentrant-play,after'
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'reentrant-play,after').len > 0
	assert app.js_messages == []
	media_lifecycle_raw_owner_balance(runtime, document, 0)
}

fn test_media_raw_play_pause_scripting_gate_strict_original_exception_and_later_owner_listener() {
	$if !darwin { return }
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	mut app, mut document, mut runtime := media_lifecycle_raw_owner_fixture(media_lifecycle_raw_owner_markup, r'
globalThis.mlVideo=document.getElementById("ml-video");globalThis.mlRuns=0;globalThis.mlPauseRuns=0;globalThis.mlChecks=[];globalThis.mlSaved=[];globalThis.mlReason={original:true};globalThis.mlReasons=[];mlVideo.event={sentinel:true};document.event={sentinel:true};0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	media_lifecycle_raw_owner_probe(mut runtime, document)!
	mut video := document.get_element_by_id('ml-video')?
	native_video := unsafe { &dom.EventTarget(video) }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	body := r'"use strict";mlRuns++;mlSaved.push(event);mlChecks.push(arguments.length===1&&event===arguments[0]&&this===mlVideo&&event.target===mlVideo&&event.currentTarget===mlVideo&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event&&__mediaLifecycleRawOwnerContext());try{void arguments.callee;mlChecks.push(false)}catch(error){mlChecks.push(error instanceof TypeError)}this.onplay=null;globalThis.mlLiveName=onplay;throw mlReason;'
	pause_body := r'mlPauseRuns++;mlSaved.push(event);mlChecks.push(event.isTrusted&&this===mlVideo&&window.event===event&&__mediaLifecycleRawOwnerContext());return false;'
	video.set_attribute_value('onplay', body)
	video.set_attribute_value('onpause', pause_body)
	play_slot := native_video.data.event_handler('play') or { panic('Strict play slot missing') }
	pause_slot := native_video.data.event_handler('pause') or { panic('Raw pause slot missing') }
	mut owner := app.page_model
	owner.set_is_scripting_enabled(false)
	assert runtime.evaluate_host(r'
mlVideo.play().catch(reason=>mlReasons.push(reason));mlVideo.pause();mlVideo.onplay===null&&mlVideo.onpause===null&&mlRuns===0&&mlPauseRuns===0
')! == 'true'
	media_lifecycle_raw_owner_drain(document)
	media_lifecycle_raw_owner_checkpoint()
	assert play_slot.value.kind == .string && play_slot.value.string_data == body
	assert pause_slot.value.kind == .string && pause_slot.value.string_data == pause_body
	assert runtime.evaluate_host('mlRuns===0&&mlPauseRuns===0&&mlSaved.length===0')! == 'true'
	media_lifecycle_raw_owner_balance(runtime, document, 0)
	owner.set_is_scripting_enabled(true)
	assert runtime.evaluate_host(r'
globalThis.mlStrict=mlVideo.onplay;globalThis.mlPause=mlVideo.onpause;
mlVideo.addEventListener("play",function(event){globalThis.mlLater=this===mlVideo&&event.currentTarget===mlVideo&&!event.defaultPrevented&&window.event===event;document.getElementById("ml-result").textContent="later media lifecycle listener"});
mlVideo.play().catch(reason=>mlReasons.push(reason));mlVideo.pause();typeof mlStrict==="function"&&mlStrict.name==="onplay"&&mlStrict.length===1&&mlVideo.onplay===mlStrict&&typeof mlPause==="function"&&mlPause.name==="onpause"&&mlVideo.onpause===mlPause&&mlRuns===0
')! == 'true'
	strict_callback := native_video.get_current_value_of_event_handler('play') or { panic('Strict play callback missing') }
	assert strict_callback.compiled_source_text_ == 'function onplay(event) {\n${body}\n}'
	assert runtime.javascript_event_handler(native_video, 'play')! == runtime.evaluate_host_value('mlStrict')!
	media_lifecycle_raw_owner_drain(document)
	media_lifecycle_raw_owner_checkpoint()
	assert runtime.evaluate_host('mlRuns===1&&mlPauseRuns===1&&mlChecks.length===3&&mlChecks.every(Boolean)&&mlLiveName===null&&mlVideo.onplay===null&&mlVideo.onpause===mlPause&&mlLater&&mlSaved.length===2&&!mlSaved[0].defaultPrevented&&mlSaved[1].defaultPrevented&&window.event===undefined')! == 'true'
	assert !native_video.data.has_event_handler('play') && native_video.data.has_event_handler('pause')
	assert video.get_attribute_value('onplay') == body && video.get_attribute_value('onpause') == pause_body
	assert settings.realm().reported_exceptions.len == 1
	reported := settings.realm().reported_exceptions[0].value.as_webidl_value()!
	assert runtime.actual_webidl_value(reported)! == runtime.evaluate_host_value('mlReason')!
	for index in 0 .. 2 {
		event := runtime.native_event(runtime.evaluate_host_value('mlSaved[${index}]')!)!
		media_lifecycle_raw_owner_event(mut runtime, event, 'mlSaved[${index}]')!
	}
	app.poll_javascript_tasks()
	assert document.get_element_by_id('ml-result')?.text_content()? == 'later media lifecycle listener'
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'later media lifecycle listener').len > 0
	assert app.js_messages == []
	media_lifecycle_raw_owner_balance(runtime, document, 1)
}
