module main

import browserjs
import dom
import html
import json2
import page
import time

const media_error_host_owner_markup = '<!doctype html><style>html,body{margin:0}#mhe-video{display:block;width:180px;height:60px}#mhe-result{position:absolute;top:100px;left:0}</style><video id="mhe-video"></video><div id="mhe-result">waiting</div>'

@[heap]
struct MediaErrorHostOwnerState {
mut:
	promises []&dom.Promise
}

fn media_error_host_owner_fixture(markup string, source string) !(&BrowserApp, &dom.Document, &browserjs.Runtime) {
	mut owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{
		value: 'https://media-error-host-owner.example.test/'
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

fn media_error_host_owner_take_task(document &dom.Document) ?&html.Task {
	mut queue := html.main_thread_event_loop().task_queue()
	return queue.take_first_runnable_matching(fn [document] (task &html.Task) bool {
		owner := task.document() or { return false }
		return task.source() == .media_element && voidptr(owner) == voidptr(document)
	})
}

fn media_error_host_owner_drain(document &dom.Document) {
	mut count := 0
	for {
		task := media_error_host_owner_take_task(document) or { break }
		count++
		assert count < 100
		task.execute()
	}
}

fn media_error_host_owner_balance(runtime &browserjs.Runtime, document &dom.Document) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn media_error_host_owner_pending(mut runtime browserjs.Runtime, document &dom.Document, mut media html.HTMLMediaElement) ! {
	media.set_source('/selected.mp4')
	media.set_fetch_hook(fn (_ dom.URL, _ u64) !html.MediaResourceResponse {
		return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 20 }
	})
	media.load()!
	media_error_host_owner_drain(document)
	assert media.ready_state() == .have_metadata && media.error() == none
	assert runtime.evaluate_host(r'globalThis.mheFirst=mheVideo.play();globalThis.mheSecond=mheVideo.play();for(const [index,promise] of [mheFirst,mheSecond].entries())promise.catch(reason=>{mheReasons.push(reason);mheOrder.push(index===0?"first":"second")});mheFirst instanceof Promise&&mheSecond instanceof Promise&&mheFirst!==mheSecond&&!mheVideo.paused&&mheVideo.error===null&&mheReasons.length===0')! == 'true'
	media_error_host_owner_drain(document)
	assert runtime.evaluate_host('mheOrder.length===0&&mheReasons.length===0')! == 'true'
}

fn media_error_host_owner_queue_failure(media &html.HTMLMediaElement, state &MediaErrorHostOwnerState, message string) {
	// Scheduling is controlled host input through the real media task source;
	// this exercises the translated failure algorithm, not a backend callback.
	media.queue_a_media_element_task(fn [media, state, message] () {
		mut current := unsafe { &html.HTMLMediaElement(media) }
		mut saved := unsafe { &MediaErrorHostOwnerState(state) }
		saved.promises = current.take_pending_play_promises()
		assert saved.promises.len == 2
		for promise in saved.promises {
			capability := promise.webidl_promise() or { panic('Missing actual native play capability') }
			assert promise.state() == .pending && capability.state == .pending
		}
		current.handle_media_source_failure(saved.promises, message)
	})
}

fn test_native_media_error_getter_exposes_actual_parsed_created_failures_and_retains_old_snapshots_after_load() {
	$if !darwin {
		return
	}
	body := r'const failure=this.error;mheErrors.push(failure);mheEvents.push(event);mheChecks.push(arguments.length===1&&event===arguments[0]&&event.target===this&&event.currentTarget===this&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event&&failure instanceof MediaError&&Object.prototype.toString.call(failure)==="[object MediaError]"&&failure===this.error&&error===failure&&failure.code===mheExpectedCode&&failure.message===mheExpectedMessage&&networkState===mheExpectedNetwork);document.getElementById("mhe-result").textContent="native media error record painted";return false;'
	markup := media_error_host_owner_markup.replace('<video id="mhe-video">', '<video id="mhe-video" onerror="${body.replace('"', '&quot;')}">')
	mut app, mut document, mut runtime := media_error_host_owner_fixture(markup, r'
globalThis.mheVideo=document.getElementById("mhe-video");globalThis.mheErrors=[];globalThis.mheEvents=[];globalThis.mheChecks=[];globalThis.mheExpectedCode=4;globalThis.mheExpectedNetwork=3;globalThis.mheExpectedMessage="";globalThis.error={sentinel:"global"};document.error={sentinel:"document"};
globalThis.mheAudio=document.createElement("audio");mheAudio.id="mhe-audio";mheAudio.setAttribute("onerror",mheVideo.getAttribute("onerror"));document.body.appendChild(mheAudio);void mheAudio.paused;0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	video := document.get_element_by_id('mhe-video')?
	audio := document.get_element_by_id('mhe-audio')?
	mut video_media := html.html_media_element_for_dom_element(video)?
	mut audio_media := html.html_media_element_for_dom_element(audio)?
	message := 'Selected decoder \x00 🎬 unavailable\r\n'
	assert runtime.evaluate_host('mheExpectedMessage=${json2.encode(message)};mheVideo.error===null&&mheAudio.error===null&&typeof mheVideo.onerror==="function"&&typeof mheAudio.onerror==="function"')! == 'true'
	for media in [video_media, audio_media] {
		mut current := unsafe { &html.HTMLMediaElement(media) }
		current.set_source('/unsupported.mp4')
		current.set_fetch_hook(fn [message] (url dom.URL, offset u64) !html.MediaResourceResponse {
			assert url.serialize() == 'https://media-error-host-owner.example.test/unsupported.mp4' && offset == 0
			return error(message)
		})
		mut failed := false
		// Resource selection dispatches synchronously in V. The callback reads
		// the actual native JS getter rather than a test host's model probe.
		current.select_resource() or { failed = true }
		assert failed && current.error()?.code() == .src_not_supported
	}
	assert runtime.evaluate_host('mheErrors.length===2&&mheChecks.length===2&&mheChecks.every(Boolean)&&mheErrors[0]===mheVideo.error&&mheErrors[1]===mheAudio.error&&mheErrors[0]!==mheErrors[1]&&mheErrors.every(record=>record.code===MediaError.MEDIA_ERR_SRC_NOT_SUPPORTED&&record.message===mheExpectedMessage)&&mheEvents.every(event=>event.defaultPrevented)&&document.error.sentinel==="document"&&globalThis.error.sentinel==="global"&&window.event===undefined')! == 'true'
	for index, media in [video_media, audio_media] {
		wrapper := runtime.evaluate_host_value('mheErrors[${index}]')!
		assert voidptr(runtime.native_media_error(wrapper)!) == voidptr(media.error()?)
		assert runtime.javascript_media_error(media.error()?)! == wrapper
	}
	video_media.set_source(none)
	assert runtime.evaluate_host('mheVideo.load();mheVideo.error===null&&mheAudio.error===mheErrors[1]&&mheErrors[0].code===4&&mheErrors[0].message===mheExpectedMessage')! == 'true'
	media_error_host_owner_drain(document)
	decode_message := 'Decode \x00 🎞 failure'
	assert runtime.evaluate_host('mheExpectedCode=3;mheExpectedNetwork=1;mheExpectedMessage=${json2.encode(decode_message)};true')! == 'true'
	video_media.set_decoder_error(decode_message)
	video_media.set_decoder_error('ignored duplicate decoder error')
	assert runtime.evaluate_host('mheErrors.length===3&&mheChecks.every(Boolean)&&mheVideo.error===mheErrors[2]&&mheErrors[2]!==mheErrors[0]&&mheErrors[2].code===MediaError.MEDIA_ERR_DECODE&&mheErrors[2].message===mheExpectedMessage')! == 'true'
	assert video_media.event_count('error') == 2
	assert runtime.evaluate_host('mheVideo.load();mheVideo.error===null&&mheErrors[2].message===mheExpectedMessage')! == 'true'
	video_media.set_ready_state(.have_metadata)
	media_error_host_owner_drain(document)
	assert runtime.evaluate_host('mheExpectedCode=2;mheExpectedMessage="Connection interrupted";true')! == 'true'
	video_media.process_media_data(.interrupted)
	assert runtime.evaluate_host('mheErrors.length===4&&mheChecks.length===4&&mheChecks.every(Boolean)&&mheVideo.error===mheErrors[3]&&mheErrors[3]!==mheErrors[2]&&mheErrors[3].code===MediaError.MEDIA_ERR_NETWORK&&mheErrors[3].message==="Connection interrupted"&&mheAudio.error===mheErrors[1]&&mheErrors[0].message===mheErrors[1].message&&mheErrors[2].code===3&&window.event===undefined')! == 'true'
	assert video_media.event_count('error') == 3 && audio_media.event_count('error') == 1
	app.poll_javascript_tasks()
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'native media error record painted').len > 0
	assert app.js_messages == []
	media_error_host_owner_balance(runtime, document)
}

fn test_native_media_error_is_visible_during_failure_before_play_reactions_and_future_typed_rejections() {
	$if !darwin {
		return
	}
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	mut app, mut document, mut runtime := media_error_host_owner_fixture(media_error_host_owner_markup, r'globalThis.mheVideo=document.getElementById("mhe-video");globalThis.mheOrder=[];globalThis.mheReasons=[];globalThis.mheErrors=[];globalThis.mheChecks=[];0')!
	defer {
		runtime.close()
		document.finalize()
	}
	mut media := html.html_media_element_for_dom_element(document.get_element_by_id('mhe-video')?)?
	media_error_host_owner_pending(mut runtime, document, mut media)!
	message := 'Dedicated decoder \x00 🎬 failure\r\n'
	body := r'mheOrder.push("error");mheErrors.push(this.error);mheChecks.push(arguments.length===1&&event===arguments[0]&&event.target===this&&event.currentTarget===this&&event.isTrusted&&window.event===event&&error===this.error&&this.error instanceof MediaError&&this.error.code===4&&this.error.message===mheExpectedMessage&&this.networkState===3&&mheReasons.length===0);document.getElementById("mhe-result").textContent="native error before play rejection";return false;'
	assert runtime.evaluate_host('mheExpectedMessage=${json2.encode(message)};mheVideo.setAttribute("onerror",${json2.encode(body)});globalThis.mheHandler=mheVideo.onerror;typeof mheHandler==="function"&&mheHandler.length===1&&mheVideo.onerror===mheHandler')! == 'true'
	assert runtime.evaluate_host(r'mheVideo.addEventListener("error",function(event){mheOrder.push("later");mheChecks.push(this.error===mheErrors[0]&&this.error.code===4&&event.isTrusted&&event.defaultPrevented&&mheReasons.length===0)});true')! == 'true'
	state := &MediaErrorHostOwnerState{}
	media_error_host_owner_queue_failure(media, state, message)
	assert runtime.evaluate_host('mheVideo.error===null&&mheOrder.length===0')! == 'true'
	(media_error_host_owner_take_task(document) or { panic('Missing controlled native failure task') }).execute()
	mut loop := html.main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
	assert runtime.evaluate_host('mheOrder.join(",")==="error,later,first,second"&&mheChecks.length===2&&mheChecks.every(Boolean)&&mheErrors[0]===mheVideo.error&&mheReasons.length===2&&mheReasons[0]===mheReasons[1]&&mheReasons[0] instanceof DOMException&&mheReasons[0].name==="NotSupportedError"&&mheReasons[0].code===9&&mheReasons[0].message==="Media is not supported"&&mheErrors[0].message===mheExpectedMessage&&window.event===undefined')! == 'true'
	for promise in state.promises {
		assert promise.state() == .rejected
	}
	assert runtime.evaluate_host(r'globalThis.mheFutureReasons=[];for(const promise of [mheVideo.play(),mheVideo.play()])promise.catch(reason=>mheFutureReasons.push(reason));mheErrors[0]===mheVideo.error')! == 'true'
	loop.perform_a_microtask_checkpoint()
	assert runtime.evaluate_host('mheFutureReasons.length===2&&mheFutureReasons[0]!==mheFutureReasons[1]&&mheFutureReasons.every(reason=>reason instanceof DOMException&&reason.name==="NotSupportedError"&&reason.code===9&&reason.message===mheExpectedMessage)&&mheVideo.error===mheErrors[0]&&mheOrder.join(",")==="error,later,first,second"')! == 'true'
	assert media.event_count('error') == 1 && media_error_host_owner_take_task(document) == none
	app.poll_javascript_tasks()
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'native error before play rejection').len > 0
	assert app.js_messages == []
	media_error_host_owner_balance(runtime, document)
}

fn test_native_media_error_getter_becomes_null_inside_reentrant_load_while_old_record_and_play_batch_survive() {
	$if !darwin {
		return
	}
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	mut app, mut document, mut runtime := media_error_host_owner_fixture(media_error_host_owner_markup, r'globalThis.mheVideo=document.getElementById("mhe-video");globalThis.mheOrder=[];globalThis.mheReasons=[];globalThis.mheErrors=[];globalThis.mheChecks=[];0')!
	defer {
		runtime.close()
		document.finalize()
	}
	mut media := html.html_media_element_for_dom_element(document.get_element_by_id('mhe-video')?)?
	media_error_host_owner_pending(mut runtime, document, mut media)!
	media.set_source(none)
	message := 'Reset decoder \x00 🎬 failure'
	body := r'const saved=this.error;mheErrors.push(saved);mheOrder.push("before-load");mheChecks.push(saved===error&&saved===this.error&&saved instanceof MediaError&&saved.code===4&&saved.message===mheExpectedMessage&&mheReasons.length===0&&event.isTrusted&&event.target===this&&event.currentTarget===this);this.load();mheOrder.push("after-load");mheChecks.push(this.error===null&&error===null&&this.networkState===0&&this.paused&&saved.code===4&&saved.message===mheExpectedMessage);document.getElementById("mhe-result").textContent="native error cleared during callback";return false;'
	assert runtime.evaluate_host('mheExpectedMessage=${json2.encode(message)};mheVideo.setAttribute("onerror",${json2.encode(body)});globalThis.mheReset=mheVideo.onerror;typeof mheReset==="function"&&mheReset.length===1&&mheVideo.onerror===mheReset')! == 'true'
	assert runtime.evaluate_host(r'mheVideo.addEventListener("error",function(event){mheOrder.push("later");mheChecks.push(this.error===null&&mheErrors[0].code===4&&mheErrors[0].message===mheExpectedMessage&&event.defaultPrevented&&mheReasons.length===0)});true')! == 'true'
	state := &MediaErrorHostOwnerState{}
	media_error_host_owner_queue_failure(media, state, message)
	(media_error_host_owner_take_task(document) or { panic('Missing reentrant native failure task') }).execute()
	media_error_host_owner_drain(document)
	mut loop := html.main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
	assert runtime.evaluate_host('mheOrder.join(",")==="before-load,after-load,later"&&mheChecks.length===3&&mheChecks.every(Boolean)&&mheReasons.length===0&&mheVideo.error===null&&mheErrors[0].code===4&&mheErrors[0].message===mheExpectedMessage&&window.event===undefined')! == 'true'
	assert media.error() == none && media.event_count('error') == 1
	for promise in state.promises {
		assert promise.state() == .pending
	}
	old_wrapper := runtime.evaluate_host_value('mheErrors[0]')!
	old_record := runtime.native_media_error(old_wrapper)!
	assert old_record.code() == .src_not_supported && old_record.message() == message
	assert runtime.javascript_media_error(old_record)! == old_wrapper
	// The real algorithm skips captured-batch rejection when load cleared the
	// error. Resolve only for teardown after proving native and JS state above.
	media.resolve_pending_play_promises(state.promises)
	loop.perform_a_microtask_checkpoint()
	app.poll_javascript_tasks()
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'native error cleared during callback').len > 0
	assert app.js_messages == []
	media_error_host_owner_balance(runtime, document)
}
