module main

import browserjs
import dom
import html
import json2
import page
import time

const media_error_raw_owner_markup = '<!doctype html><style>
html,body{margin:0}#mre-video{display:block;width:180px;height:60px}
#mre-result{position:absolute;top:100px;left:0}
</style><form id="mre-form"><video id="mre-video"></video></form><div id="mre-result">waiting</div>'

@[heap]
struct MediaErrorRawOwnerState {
mut:
	promises []&dom.Promise
	events   []&dom.Event
	code     html.MediaErrorCode = .src_not_supported
	message  string
	fetches  int
}

fn media_error_raw_owner_fixture(markup string, source string) !(&BrowserApp, &dom.Document, &browserjs.Runtime) {
	mut owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{
		value: 'https://media-error-raw-owner.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [source], runtime, mut messages)
	assert messages == []
	mut app := &BrowserApp{
		page_model:      owner
		document:        document
		js_runtime:      runtime
		viewport_width:  320
		viewport_height: 240
	}
	app.relayout(320, 240 + app.chrome_height())
	assert document.layout_is_up_to_date() && document.paintable_box() != none
	return app, document, runtime
}

fn media_error_raw_owner_take_task(document &dom.Document) ?&html.Task {
	mut queue := html.main_thread_event_loop().task_queue()
	return queue.take_first_runnable_matching(fn [document] (task &html.Task) bool {
		owner := task.document() or { return false }
		return task.source() == .media_element && voidptr(owner) == voidptr(document)
	})
}

fn media_error_raw_owner_drain(document &dom.Document) {
	mut count := 0
	for {
		task := media_error_raw_owner_take_task(document) or { break }
		count++
		assert count < 100
		task.execute()
	}
}

fn media_error_raw_owner_probe(mut runtime browserjs.Runtime, document &dom.Document, media &html.HTMLMediaElement, state &MediaErrorRawOwnerState, name string) ! {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	handle := voidptr(&runtime)
	actual_true := runtime.evaluate_host_value('true')!
	runtime.define_value_host_function(name, fn [settings, handle, actual_true, media, state] (_ voidptr, args []voidptr) !voidptr {
		owner := unsafe { &browserjs.Runtime(handle) }
		assert args.len == 0
		assert settings.realm().script_execution_depth > 0 && settings.realm().callback_execution_depth > 0
		assert owner.libjs_vm().has_running_execution_context()
		assert voidptr(html.current_principal_settings_object()) == voidptr(settings)
		assert voidptr(html.incumbent_settings_object()) == voidptr(settings)
		// HTMLMediaElement.error has no native JS getter yet. These assertions
		// inspect the actual V record without claiming that missing binding.
		failure := media.error() or { panic('Native error needs its MediaError') }
		assert failure.code() == state.code && failure.message() == state.message
		for promise in state.promises {
			assert promise.state() == .pending
		}
		return actual_true
	})!
}

fn media_error_raw_owner_observe(element &dom.Element, state &MediaErrorRawOwnerState) {
	callback := &dom.CallbackType{
		handle_event: fn [state] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut saved := unsafe { &MediaErrorRawOwnerState(state) }
			assert event.type_name() == 'error' && event.interface_ == .event && event.is_trusted()
			assert !event.bubbles() && !event.cancelable()
			saved.events << event
			return dom.js_undefined()
		}
	}
	unsafe { &dom.EventTarget(element) }.add_event_listener_without_options('error', dom.IDLEventListener.create(callback))
}

fn media_error_raw_owner_event(mut runtime browserjs.Runtime, event &dom.Event, expression string) ! {
	wrapper := runtime.evaluate_host_value(expression)!
	assert voidptr(runtime.native_event(wrapper)!) == voidptr(event)
	assert runtime.javascript_event(event)! == wrapper
	assert event.is_trusted() && event.current_target() == none && event.event_phase() == 0
	assert runtime.evaluate_host('${expression}.currentTarget===null&&${expression}.eventPhase===Event.NONE&&window.event===undefined')! == 'true'
}

fn media_error_raw_owner_balance(runtime &browserjs.Runtime, document &dom.Document, exceptions int) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == exceptions
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn media_error_raw_owner_queue(media &html.HTMLMediaElement, state &MediaErrorRawOwnerState, message string, take_promises bool) {
	// The V failure APIs dispatch synchronously. Supply a controlled host task
	// through the real media task source, as pinned upstream's failure callers
	// do; this does not exercise a decoder or a network backend callback.
	media.queue_a_media_element_task(fn [media, state, message, take_promises] () {
		mut current_media := unsafe { &html.HTMLMediaElement(media) }
		mut observation := unsafe { &MediaErrorRawOwnerState(state) }
		if take_promises {
			observation.promises = current_media.take_pending_play_promises()
			assert observation.promises.len == 2
			for promise in observation.promises {
				capability := promise.webidl_promise() or { panic('Missing native play capability') }
				assert promise.state() == .pending && capability.state == .pending
			}
			assert voidptr(observation.promises[0].webidl_promise() or { panic('Missing first capability') }) != voidptr(observation.promises[1].webidl_promise() or { panic('Missing second capability') })
		}
		current_media.handle_media_source_failure(if take_promises {
			observation.promises
		} else {
			[]&dom.Promise{}
		}, message)
	})
}

fn media_error_raw_owner_pending(mut runtime browserjs.Runtime, document &dom.Document, mut media html.HTMLMediaElement) ! {
	media.set_source('/selected.mp4')
	media.set_fetch_hook(fn (_ dom.URL, _ u64) !html.MediaResourceResponse {
		return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 20 }
	})
	media.load()!
	media_error_raw_owner_drain(document)
	assert media.ready_state() == .have_metadata && media.error() == none
	assert runtime.evaluate_host(r'globalThis.mreFirst=mreVideo.play();globalThis.mreSecond=mreVideo.play();for(const [index,promise] of [mreFirst,mreSecond].entries())promise.catch(reason=>{mreReasons.push(reason);mreOrder.push(index===0?"first":"second")});mreFirst instanceof Promise&&mreSecond instanceof Promise&&mreFirst!==mreSecond&&!mreVideo.paused&&mreReasons.length===0')! == 'true'
	media_error_raw_owner_drain(document)
	assert runtime.evaluate_host('mreOrder.length===0&&mreReasons.length===0')! == 'true'
}

fn test_media_raw_error_parsed_created_scopes_real_resource_failures_and_decode_network_records() {
	$if !darwin {
		return
	}
	body := r'mreRuns++;mreOrder.push(this.id+":error");mreScopes.push(scopeKey);delete this.scopeKey;mreScopes.push(scopeKey);delete document.scopeKey;mreScopes.push(scopeKey);document.scopeKey="document";this.scopeKey=this.id==="mre-video"?"parsed element":"created element";mreSaved.push(event);mreChecks.push(arguments.length===1&&event===arguments[0]&&(this===mreVideo||this===mreAudio)&&event.target===this&&event.currentTarget===this&&event instanceof Event&&event.type==="error"&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event&&document===mreDocument&&getElementById("mre-result")===mreResult&&networkState===mreExpectedNetwork&&readyState===mreExpectedReady&&paused===true&&(this===mreVideo?__mediaErrorRawVideoRecord():__mediaErrorRawAudioRecord()));getElementById("mre-result").textContent="raw native media error painted";this.style.color="rgb(0,128,0)";return false;'
	attribute_body := body.replace('"', '&quot;')
	markup := media_error_raw_owner_markup.replace('<video id="mre-video">', '<video id="mre-video" onerror="${attribute_body}">')
	mut app, mut document, mut runtime := media_error_raw_owner_fixture(markup, r'
globalThis.mreVideo=document.getElementById("mre-video");globalThis.mreDocument=document;globalThis.mreResult=document.getElementById("mre-result");globalThis.mreForm=document.getElementById("mre-form");globalThis.mreRuns=0;globalThis.mreOrder=[];globalThis.mreScopes=[];globalThis.mreSaved=[];globalThis.mreChecks=[];globalThis.scopeKey="global";globalThis.mreExpectedNetwork=3;globalThis.mreExpectedReady=0;
document.scopeKey="document";mreForm.scopeKey="nearest form";mreVideo.scopeKey="parsed element";mreVideo.event={sentinel:true};document.event={sentinel:true};globalThis.mreAudio=document.createElement("audio");mreAudio.id="mre-audio";mreAudio.setAttribute("onerror",mreVideo.getAttribute("onerror"));document.body.appendChild(mreAudio);mreAudio.scopeKey="created element";void mreAudio.paused;0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	video := document.get_element_by_id('mre-video')?
	audio := document.get_element_by_id('mre-audio')?
	mut video_media := html.html_media_element_for_dom_element(video)?
	mut audio_media := html.html_media_element_for_dom_element(audio)?
	video_state := &MediaErrorRawOwnerState{ message: 'Selected decoder \x00 🎬 unavailable\r\n' }
	audio_state := &MediaErrorRawOwnerState{ message: 'Selected decoder \x00 🎬 unavailable\r\n' }
	media_error_raw_owner_probe(mut runtime, document, video_media, video_state, '__mediaErrorRawVideoRecord')!
	media_error_raw_owner_probe(mut runtime, document, audio_media, audio_state, '__mediaErrorRawAudioRecord')!
	assert runtime.evaluate_host('globalThis.mreVideoError=mreVideo.onerror;globalThis.mreAudioError=mreAudio.onerror;typeof mreVideoError==="function"&&typeof mreAudioError==="function"&&mreVideoError!==mreAudioError&&mreVideoError.name==="onerror"&&mreAudioError.name==="onerror"&&mreVideoError.length===1&&mreAudioError.length===1&&mreVideo.onerror===mreVideoError&&mreAudio.onerror===mreAudioError&&!Object.hasOwn(mreVideo,"onerror")&&!Object.hasOwn(mreAudio,"onerror")&&mreRuns===0')! == 'true'
	for element in [video, audio] {
		native := unsafe { &dom.EventTarget(element) }
		callback := native.get_current_value_of_event_handler('error') or { panic('Cached media error callback missing') }
		assert callback.compiled_source_text_ == 'function onerror(event) {\n${body}\n}'
	}
	for index, media in [video_media, audio_media] {
		state := if index == 0 { video_state } else { audio_state }
		media_error_raw_owner_observe(if index == 0 { video } else { audio }, state)
		mut current := unsafe { &html.HTMLMediaElement(media) }
		current.set_source('/unsupported.mp4')
		current.set_fetch_hook(fn [state] (url dom.URL, offset u64) !html.MediaResourceResponse {
			assert url.serialize() == 'https://media-error-raw-owner.example.test/unsupported.mp4' && offset == 0
			mut seen := unsafe { &MediaErrorRawOwnerState(state) }
			seen.fetches++
			return error(seen.message)
		})
		mut failed := false
		// Actual translated selection invokes the failing fetch hook, installs
		// MediaError, and dispatches error synchronously; no queued-task parity.
		current.select_resource() or { failed = true }
		assert failed && state.fetches == 1 && current.event_count('error') == 1
		assert current.error()?.code() == .src_not_supported && current.error()?.message() == state.message
		assert state.events.len == 1 && state.events[0].default_prevented()
	}
	assert runtime.evaluate_host('mreRuns===2&&mreOrder.join(",")==="mre-video:error,mre-audio:error"&&mreChecks.every(Boolean)&&mreScopes.join(",")==="parsed element,document,global,created element,document,global"&&mreForm.scopeKey==="nearest form"')! == 'true'
	// These public V algorithms also produce native Events with their own
	// error codes. Their delivery remains synchronous in this translation.
	video_media.set_source(none)
	video_media.load()!
	video_media.set_ready_state(.have_metadata)
	media_error_raw_owner_drain(document)
	mut video_observation := unsafe { &MediaErrorRawOwnerState(video_state) }
	video_observation.code = .decode
	video_observation.message = 'Decode \x00 🎞 failure'
	assert runtime.evaluate_host('mreExpectedNetwork=1;mreExpectedReady=1;true')! == 'true'
	video_media.set_decoder_error(video_observation.message)
	video_media.set_decoder_error('ignored second decoder error')
	assert video_media.event_count('error') == 2 && video_media.error()?.message() == video_observation.message
	video_media.load()!
	video_media.set_ready_state(.have_metadata)
	media_error_raw_owner_drain(document)
	video_observation.code = .network
	video_observation.message = 'Connection interrupted'
	video_media.process_media_data(.interrupted)
	assert video_media.event_count('error') == 3 && video_media.network_state() == .idle
	assert runtime.evaluate_host('mreRuns===4&&mreChecks.length===4&&mreChecks.every(Boolean)&&mreSaved.length===4&&mreSaved.every(event=>event.defaultPrevented)&&mreVideo.onerror===mreVideoError&&mreAudio.onerror===mreAudioError&&window.event===undefined')! == 'true'
	for index, event in [video_state.events[0], audio_state.events[0], video_state.events[1],
		video_state.events[2]] {
		media_error_raw_owner_event(mut runtime, event, 'mreSaved[${index}]')!
	}
	app.poll_javascript_tasks()
	assert document.get_element_by_id('mre-result')?.text_content()? == 'raw native media error painted'
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'raw native media error painted').len > 0
	assert app.js_messages == []
	media_error_raw_owner_balance(runtime, document, 0)
}

fn test_media_raw_error_prequeued_replacement_reentry_removal_and_captured_play_promise_order() {
	$if !darwin {
		return
	}
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	body := r'mreOrder.push("old");return false;'
	markup := media_error_raw_owner_markup.replace('<video id="mre-video">', '<video id="mre-video" onerror="${body.replace('"', '&quot;')}">')
	mut app, mut document, mut runtime := media_error_raw_owner_fixture(markup, r'
globalThis.mreVideo=document.getElementById("mre-video");globalThis.mreOrder=[];globalThis.mreSaved=[];globalThis.mreChecks=[];globalThis.mreReasons=[];globalThis.mreOriginal=mreVideo.onerror;
globalThis.mreIDL=function(event){mreOrder.push("idl");mreSaved.push(event);mreChecks.push(arguments.length===1&&this===mreVideo&&event.target===this&&event.currentTarget===this&&event.isTrusted&&window.event===event);return false};0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	video := document.get_element_by_id('mre-video')?
	native := unsafe { &dom.EventTarget(video) }
	slot := native.data.event_handler('error') or { panic('Error slot missing') }
	listener := slot.listener or { panic('Error listener missing') }
	assert runtime.evaluate_host('mreVideo.onerror=mreIDL;mreVideo.setAttribute("onerror",${json2.encode(body)});globalThis.mreEqual=mreVideo.onerror;mreEqual!==mreOriginal&&mreEqual!==mreIDL&&mreVideo.onerror===mreEqual')! == 'true'
	assert voidptr(native.data.event_handler('error') or { panic('Retained error slot missing') }) == voidptr(slot)
	assert voidptr(slot.listener or { panic('Retained error listener missing') }) == voidptr(listener)
	mut media := html.html_media_element_for_dom_element(video)?
	state := &MediaErrorRawOwnerState{ message: 'Dedicated decoder \x00 🎬 failure' }
	media_error_raw_owner_probe(mut runtime, document, media, state, '__mediaErrorRawPendingRecord')!
	media_error_raw_owner_pending(mut runtime, document, mut media)!
	actual_true := runtime.evaluate_host_value('true')!
	runtime.define_value_host_function('__mediaErrorRawQueueAgain', fn [media, state, actual_true] (_ voidptr, args []voidptr) !voidptr {
		assert args.len == 0
		media_error_raw_owner_queue(media, state, 'reentrant dedicated failure', false)
		return actual_true
	})!
	assert runtime.evaluate_host(r'mreVideo.addEventListener("error",function(event){mreOrder.push("later");mreChecks.push(this===mreVideo&&event.target===this&&event.currentTarget===this&&event.isTrusted&&window.event===event)});true')! == 'true'
	media_error_raw_owner_observe(video, state)
	media_error_raw_owner_queue(media, state, state.message, true)
	replacement := r'mreOrder.push("replacement");mreSaved.push(event);mreChecks.push(arguments.length===1&&event===arguments[0]&&this===mreVideo&&event.target===this&&event.currentTarget===this&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event&&networkState===3&&readyState===1&&!paused&&mreReasons.length===0&&__mediaErrorRawPendingRecord());this.onerror=mreIDL;__mediaErrorRawQueueAgain();document.getElementById("mre-result").textContent="reentrant raw media error painted";return false;'
	assert runtime.evaluate_host('mreVideo.setAttribute("onerror",${json2.encode(replacement)});typeof mreVideo.onerror==="function"&&mreVideo.onerror!==mreEqual&&mreOrder.length===0')! == 'true'
	(media_error_raw_owner_take_task(document) or { panic('Missing controlled source failure task') }).execute()
	mut loop := html.main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
	assert runtime.evaluate_host('mreOrder.join(",")==="replacement,later,first,second"&&mreReasons.length===2&&mreReasons[0]===mreReasons[1]&&mreReasons[0] instanceof DOMException&&mreReasons[0].name==="NotSupportedError"&&mreReasons[0].code===9&&mreReasons[0].message==="Media is not supported"&&mreVideo.onerror===mreIDL')! == 'true'
	assert state.promises.len == 2
	for promise in state.promises {
		capability := promise.webidl_promise() or { panic('Missing rejected play capability') }
		assert promise.state() == .rejected && capability.state == .rejected
		assert capability.result.dom_exception_?.name() == 'NotSupportedError'
		assert capability.result.dom_exception_?.message() == 'Media is not supported'
	}
	(media_error_raw_owner_take_task(document) or { panic('Missing reentrant source failure task') }).execute()
	assert media_error_raw_owner_take_task(document) == none
	assert runtime.evaluate_host('mreOrder.join(",")==="replacement,later,first,second,idl,later"&&mreChecks.length===4&&mreChecks.every(Boolean)&&mreSaved.every(event=>event.defaultPrevented)')! == 'true'
	assert voidptr(slot.listener or { panic('Reentrant error listener missing') }) == voidptr(listener)
	media_error_raw_owner_queue(media, state, 'removed raw body', false)
	assert runtime.evaluate_host('mreVideo.removeAttribute("onerror");mreVideo.onerror===null')! == 'true'
	assert !native.data.has_event_handler('error')
	media_error_raw_owner_drain(document)
	assert runtime.evaluate_host('mreOrder.join(",")==="replacement,later,first,second,idl,later,later"&&mreSaved.length===2')! == 'true'
	assert runtime.evaluate_host('mreVideo.onerror=mreIDL;mreVideo.removeAttribute("onerror");mreVideo.onerror===mreIDL')! == 'true'
	media_error_raw_owner_queue(media, state, 'retained IDL without attribute', false)
	media_error_raw_owner_drain(document)
	// Removing the raw slot removed its listener. Reinstalling the IDL slot
	// appends its new listener after the existing ordinary listener.
	assert runtime.evaluate_host('mreOrder.join(",")==="replacement,later,first,second,idl,later,later,later,idl"&&mreChecks.length===7&&mreChecks.every(Boolean)&&mreSaved.length===3&&mreSaved.every(event=>event.defaultPrevented)&&window.event===undefined')! == 'true'
	assert media.event_count('error') == 4 && state.events.len == 4
	for index, event in [state.events[0], state.events[1], state.events[3]] {
		media_error_raw_owner_event(mut runtime, event, 'mreSaved[${index}]')!
	}
	app.poll_javascript_tasks()
	assert document.get_element_by_id('mre-result')?.text_content()? == 'reentrant raw media error painted'
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'reentrant raw media error painted').len > 0
	assert app.js_messages == []
	media_error_raw_owner_balance(runtime, document, 0)
}

fn test_media_raw_error_reentrant_load_resets_failure_and_keeps_the_captured_batch_pending() {
	$if !darwin {
		return
	}
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	mut app, mut document, mut runtime := media_error_raw_owner_fixture(media_error_raw_owner_markup, r'globalThis.mreVideo=document.getElementById("mre-video");globalThis.mreOrder=[];globalThis.mreReasons=[];globalThis.mreSaved=[];globalThis.mreChecks=[];0')!
	defer {
		runtime.close()
		document.finalize()
	}
	video := document.get_element_by_id('mre-video')?
	mut media := html.html_media_element_for_dom_element(video)?
	state := &MediaErrorRawOwnerState{ message: 'failure reset during raw error' }
	media_error_raw_owner_probe(mut runtime, document, media, state, '__mediaErrorRawPendingRecord')!
	media_error_raw_owner_pending(mut runtime, document, mut media)!
	media.set_source(none)
	actual_true := runtime.evaluate_host_value('true')!
	runtime.define_value_host_function('__mediaErrorRawResetRecord', fn [media, state, actual_true] (_ voidptr, args []voidptr) !voidptr {
		assert args.len == 0 && media.error() == none && media.network_state() == .empty && media.paused()
		assert state.promises.len == 2
		for promise in state.promises {
			assert promise.state() == .pending
		}
		return actual_true
	})!
	body := r'mreOrder.push("before-load");mreSaved.push(event);mreChecks.push(arguments.length===1&&event===arguments[0]&&this===mreVideo&&event.isTrusted&&window.event===event&&networkState===3&&mreReasons.length===0&&__mediaErrorRawPendingRecord());this.load();mreOrder.push("after-load");mreChecks.push(networkState===0&&readyState===0&&paused===true&&__mediaErrorRawResetRecord());document.getElementById("mre-result").textContent="raw media error reset painted";return false;'
	// Replay the compact attribute and compile its native slot before adding
	// the listener whose ordering this controlled task is meant to exercise.
	assert runtime.evaluate_host('mreVideo.setAttribute("onerror",${json2.encode(body)});globalThis.mreReset=mreVideo.onerror;typeof mreReset==="function"&&mreReset.name==="onerror"&&mreReset.length===1&&mreVideo.onerror===mreReset')! == 'true'
	assert runtime.evaluate_host('mreVideo.addEventListener("error",function(event){mreOrder.push("later");mreChecks.push(this===mreVideo&&event===mreSaved[0]&&event.defaultPrevented&&window.event===event&&this.networkState===0)});true')! == 'true'
	media_error_raw_owner_observe(video, state)
	media_error_raw_owner_queue(media, state, state.message, true)
	(media_error_raw_owner_take_task(document) or { panic('Missing reset source failure task') }).execute()
	media_error_raw_owner_drain(document)
	mut loop := html.main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
	assert runtime.evaluate_host('mreOrder.join(",")==="before-load,after-load,later"&&mreReasons.length===0&&mreChecks.length===3&&mreChecks.every(Boolean)&&mreVideo.networkState===0&&mreVideo.paused&&window.event===undefined')! == 'true'
	assert media.error() == none && media.event_count('error') == 1 && state.promises.len == 2
	for promise in state.promises {
		assert promise.state() == .pending
	}
	media_error_raw_owner_event(mut runtime, state.events[0], 'mreSaved[0]')!
	// The dedicated failure algorithm skips rejection after load() cleared the
	// error, matching upstream. Settle only for teardown after proving pending.
	media.resolve_pending_play_promises(state.promises)
	loop.perform_a_microtask_checkpoint()
	app.poll_javascript_tasks()
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'raw media error reset painted').len > 0
	assert app.js_messages == []
	media_error_raw_owner_balance(runtime, document, 0)
}

fn test_media_raw_error_scripting_gate_strict_original_exception_later_listener_and_paint() {
	$if !darwin {
		return
	}
	mut app, mut document, mut runtime := media_error_raw_owner_fixture(media_error_raw_owner_markup, r'globalThis.mreVideo=document.getElementById("mre-video");globalThis.mreOrder=[];globalThis.mreSaved=[];globalThis.mreChecks=[];globalThis.mreReason={original:true};0')!
	defer {
		runtime.close()
		document.finalize()
	}
	video := document.get_element_by_id('mre-video')?
	native := unsafe { &dom.EventTarget(video) }
	mut media := html.html_media_element_for_dom_element(video)?
	state := &MediaErrorRawOwnerState{ message: 'strict source failure' }
	media_error_raw_owner_probe(mut runtime, document, media, state, '__mediaErrorRawStrictRecord')!
	body := r'"use strict";mreOrder.push("strict");mreSaved.push(event);mreChecks.push(arguments.length===1&&event===arguments[0]&&this===mreVideo&&event.target===this&&event.currentTarget===this&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event&&this.networkState===3&&__mediaErrorRawStrictRecord());try{void arguments.callee;mreChecks.push(false)}catch(error){mreChecks.push(error instanceof TypeError)}this.onerror=null;globalThis.mreLiveName=onerror;throw mreReason;'
	// A state getter flushes the compact attribute without compiling onerror,
	// preserving a raw string slot for the disabled-scripting check below.
	assert runtime.evaluate_host('mreVideo.setAttribute("onerror",${json2.encode(body)});mreVideo.paused===true')! == 'true'
	slot := native.data.event_handler('error') or { panic('Gated raw error slot missing') }
	mut owner := app.page_model
	owner.set_is_scripting_enabled(false)
	media_error_raw_owner_queue(media, state, state.message, false)
	assert runtime.evaluate_host('mreVideo.onerror===null&&mreOrder.length===0')! == 'true'
	media_error_raw_owner_drain(document)
	assert slot.value.kind == .string && slot.value.string_data == body
	assert media.event_count('error') == 1 && media.error()?.code() == .src_not_supported
	assert runtime.evaluate_host('mreOrder.length===0&&mreSaved.length===0&&mreChecks.length===0')! == 'true'
	media_error_raw_owner_balance(runtime, document, 0)
	owner.set_is_scripting_enabled(true)
	assert runtime.evaluate_host(r'globalThis.mreStrict=mreVideo.onerror;mreVideo.addEventListener("error",function(event){mreOrder.push("later");mreChecks.push(this===mreVideo&&event===mreSaved[0]&&event.isTrusted&&!event.defaultPrevented&&window.event===event);document.getElementById("mre-result").textContent="later native media error painted"});typeof mreStrict==="function"&&mreStrict.name==="onerror"&&mreStrict.length===1&&mreVideo.onerror===mreStrict')! == 'true'
	callback := native.get_current_value_of_event_handler('error') or { panic('Strict raw error callback missing') }
	assert callback.compiled_source_text_ == 'function onerror(event) {\n${body}\n}'
	media_error_raw_owner_observe(video, state)
	media_error_raw_owner_queue(media, state, state.message, false)
	media_error_raw_owner_drain(document)
	assert runtime.evaluate_host('mreOrder.join(",")==="strict,later"&&mreChecks.length===3&&mreChecks.every(Boolean)&&mreLiveName===null&&mreVideo.onerror===null&&mreSaved.length===1&&!mreSaved[0].defaultPrevented&&window.event===undefined')! == 'true'
	assert !native.data.has_event_handler('error') && video.get_attribute_value('onerror') == body
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 1
	reported := settings.realm().reported_exceptions[0].value.as_webidl_value()!
	assert runtime.actual_webidl_value(reported)! == runtime.evaluate_host_value('mreReason')!
	assert media.event_count('error') == 2 && state.events.len == 1
	media_error_raw_owner_event(mut runtime, state.events[0], 'mreSaved[0]')!
	app.poll_javascript_tasks()
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'later native media error painted').len > 0
	assert app.js_messages == []
	media_error_raw_owner_balance(runtime, document, 1)
}
