module main

import browserjs
import dom
import html
import json2
import page
import time

const media_reset_raw_owner_markup = '<!doctype html><style>
html,body{margin:0}#mrr-video{display:block;width:180px;height:60px}
#mrr-result{position:absolute;top:100px;left:0}
</style><form id="mrr-form"><video id="mrr-video"></video></form><div id="mrr-result">waiting</div>'

@[heap]
struct MediaResetRawOwnerObservation {
mut:
	events []&dom.Event
	targets []voidptr
}

fn media_reset_raw_owner_fixture(markup string, source string) !(&BrowserApp, &dom.Document, &browserjs.Runtime) {
	mut owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{
		value: 'https://media-reset-raw-owner.example.test/'
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

fn media_reset_raw_owner_take_task(document &dom.Document) ?&html.Task {
	mut queue := html.main_thread_event_loop().task_queue()
	return queue.take_first_runnable_matching(fn [document] (task &html.Task) bool {
		owner := task.document() or { return false }
		return task.source() == .media_element && voidptr(owner) == voidptr(document)
	})
}

fn media_reset_raw_owner_drain(document &dom.Document) {
	mut count := 0
	for {
		task := media_reset_raw_owner_take_task(document) or { break }
		count++
		assert count < 100
		task.execute()
	}
}

fn media_reset_raw_owner_probe(mut runtime browserjs.Runtime, document &dom.Document) ! {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	handle := voidptr(&runtime)
	actual_true := runtime.evaluate_host_value('true')!
	runtime.define_value_host_function('__mediaResetRawOwnerContext', fn [settings, handle, actual_true] (_ voidptr, args []voidptr) !voidptr {
		owner := unsafe { &browserjs.Runtime(handle) }
		assert args.len == 0
		assert settings.realm().script_execution_depth > 0 && settings.realm().callback_execution_depth > 0
		assert owner.libjs_vm().has_running_execution_context()
		assert voidptr(html.current_principal_settings_object()) == voidptr(settings)
		assert voidptr(html.incumbent_settings_object()) == voidptr(settings)
		return actual_true
	})!
}

fn media_reset_raw_owner_observe(element &dom.Element, observation &MediaResetRawOwnerObservation) {
	handle := voidptr(observation)
	callback := &dom.CallbackType{
		handle_event: fn [handle] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut saved := unsafe { &MediaResetRawOwnerObservation(handle) }
			assert event.type_name() in ['abort', 'emptied']
			assert event.interface_ == .event && event.is_trusted()
			// The handler algorithm applies exact false to the canceled flag,
			// including native reset events whose cancelable flag is false.
			assert !event.bubbles() && !event.cancelable() && event.default_prevented()
			saved.events << event
			saved.targets << voidptr(event.target() or { panic('Native reset event needs its owner') })
			return dom.js_undefined()
		}
	}
	for name in ['abort', 'emptied'] {
		unsafe { &dom.EventTarget(element) }.add_event_listener_without_options(name, dom.IDLEventListener.create(callback))
	}
}

fn media_reset_raw_owner_event(mut runtime browserjs.Runtime, event &dom.Event, expression string) ! {
	wrapper := runtime.evaluate_host_value(expression)!
	assert voidptr(runtime.native_event(wrapper)!) == voidptr(event)
	assert runtime.javascript_event(event)! == wrapper
	assert event.is_trusted() && event.current_target() == none && event.event_phase() == 0
	assert runtime.evaluate_host('${expression}.currentTarget===null&&${expression}.eventPhase===Event.NONE&&window.event===undefined')! == 'true'
}

fn media_reset_raw_owner_balance(runtime &browserjs.Runtime, document &dom.Document, exceptions int) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == exceptions
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn media_reset_raw_owner_warm_bridge(mut runtime browserjs.Runtime, media &html.HTMLMediaElement, name string, idle bool, seed_state bool) ! {
	media_handle := voidptr(media)
	actual_true := runtime.evaluate_host_value('true')!
	runtime.define_value_host_function(name, fn [media_handle, actual_true, idle, seed_state] (_ voidptr, args []voidptr) !voidptr {
		assert args.len == 0
		mut current_media := unsafe { &html.HTMLMediaElement(media_handle) }
		if idle { current_media.process_media_data(.complete) }
		if seed_state {
			// Controlled native state exposes the load reset without a resource,
			// fetch, decoder, playback request, or synthetic owner event.
			current_media.set_ready_state(.have_metadata)
			current_media.set_duration(20)
			current_media.set_current_playback_position(6)
			current_media.set_official_playback_position(6)
			current_media.set_seeking(true)
			current_media.set_paused(false)
		}
		return actual_true
	})!
}

fn test_media_raw_abort_emptied_parsed_created_scopes_reset_order_and_other_owner_tasks() {
	$if !darwin { return }
	body := r'mrrRuns++;mrrOrder.push(this.id+":"+event.type);mrrScopes.push(scopeKey);delete this.scopeKey;mrrScopes.push(scopeKey);delete document.scopeKey;mrrScopes.push(scopeKey);document.scopeKey="document";this.scopeKey=this.id==="mrr-video"?"parsed element":"created element";mrrSaved.push(event);mrrChecks.push(arguments.length===1&&event===arguments[0]&&(this===mrrVideo||this===mrrAudio)&&event.target===this&&event.currentTarget===this&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event&&document===mrrDocument&&getElementById("mrr-result")===mrrResult&&networkState===0&&readyState===0&&currentTime===0&&currentSrc===""&&Number.isNaN(duration)&&paused===true&&seeking===false&&__mediaResetRawOwnerContext());getElementById("mrr-result").textContent="raw media reset painted";this.style.color="rgb(0,128,0)";return false;'
	attribute_body := body.replace('"', '&quot;')
	markup := media_reset_raw_owner_markup.replace('<video id="mrr-video">',
		'<video id="mrr-video" onabort="${attribute_body}" onemptied="${attribute_body}">')
	mut app, mut document, mut runtime := media_reset_raw_owner_fixture(markup, r'
globalThis.mrrVideo=document.getElementById("mrr-video");globalThis.mrrDocument=document;globalThis.mrrResult=document.getElementById("mrr-result");globalThis.mrrForm=document.getElementById("mrr-form");
globalThis.mrrRuns=0;globalThis.mrrOrder=[];globalThis.mrrScopes=[];globalThis.mrrSaved=[];globalThis.mrrChecks=[];globalThis.mrrOtherRuns=0;globalThis.scopeKey="global";
document.scopeKey="document";mrrForm.scopeKey="nearest form";mrrVideo.scopeKey="parsed element";mrrVideo.event={sentinel:true};document.event={sentinel:true};
globalThis.mrrAudio=document.createElement("audio");mrrAudio.id="mrr-audio";mrrAudio.setAttribute("onabort",mrrVideo.getAttribute("onabort"));mrrAudio.setAttribute("onemptied",mrrVideo.getAttribute("onemptied"));document.body.appendChild(mrrAudio);mrrAudio.scopeKey="created element";void mrrAudio.paused;
globalThis.mrrOther=document.createElement("audio");mrrOther.id="mrr-other";document.body.appendChild(mrrOther);mrrOther.addEventListener("volumechange",function(event){mrrOtherRuns++;mrrOrder.push("other");mrrChecks.push(this===mrrOther&&event.target===this&&event.currentTarget===this&&event.isTrusted&&this.volume===0.5&&window.event===event)});
for(var mrrElement of [mrrVideo,mrrAudio])mrrElement.addEventListener("timeupdate",function(event){mrrOrder.push(this.id+":"+event.type);mrrChecks.push(event instanceof Event&&event.isTrusted&&event.target===this&&event.currentTarget===this&&!event.bubbles&&!event.cancelable&&!event.defaultPrevented&&this.networkState===0&&this.readyState===0&&!this.seeking&&this.currentTime===0&&this.paused&&window.event===event)});0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	media_reset_raw_owner_probe(mut runtime, document)!
	video := document.get_element_by_id('mrr-video')?
	audio := document.get_element_by_id('mrr-audio')?
	native_video := unsafe { &dom.EventTarget(video) }
	native_audio := unsafe { &dom.EventTarget(audio) }
	for target in [native_video, native_audio] {
		for name in ['abort', 'emptied'] {
			slot := target.data.event_handler(name) or { panic('Raw reset slot missing') }
			assert slot.value.kind == .string && slot.value.string_data == body
		}
	}
	assert runtime.evaluate_host(r'
globalThis.mrrVideoAbort=mrrVideo.onabort;globalThis.mrrVideoEmptied=mrrVideo.onemptied;globalThis.mrrAudioAbort=mrrAudio.onabort;globalThis.mrrAudioEmptied=mrrAudio.onemptied;
[mrrVideoAbort,mrrVideoEmptied,mrrAudioAbort,mrrAudioEmptied].every(value=>typeof value==="function"&&value.length===1)&&mrrVideoAbort.name==="onabort"&&mrrAudioAbort.name==="onabort"&&mrrVideoEmptied.name==="onemptied"&&mrrAudioEmptied.name==="onemptied"&&new Set([mrrVideoAbort,mrrVideoEmptied,mrrAudioAbort,mrrAudioEmptied]).size===4&&mrrVideo.onabort===mrrVideoAbort&&mrrVideo.onemptied===mrrVideoEmptied&&mrrAudio.onabort===mrrAudioAbort&&mrrAudio.onemptied===mrrAudioEmptied&&!Object.hasOwn(mrrVideo,"onabort")&&!Object.hasOwn(mrrAudio,"onemptied")&&mrrRuns===0
')! == 'true'
	for target in [native_video, native_audio] {
		alias := if voidptr(target) == voidptr(native_video) { 'mrrVideo' } else { 'mrrAudio' }
		for name in ['abort', 'emptied'] {
			callback := target.get_current_value_of_event_handler(name) or { panic('Cached reset callback missing') }
			assert callback.compiled_source_text_ == 'function on${name}(event) {\n${body}\n}'
			assert runtime.javascript_event_handler(target, name)! == runtime.evaluate_host_value('${alias}.on${name}')!
		}
	}
	// A fully fresh empty owner has no abort, emptied, or position reset task.
	assert runtime.evaluate_host('mrrVideo.load();mrrAudio.load();mrrRuns===0&&mrrOrder.length===0&&mrrVideo.networkState===0&&mrrAudio.networkState===0')! == 'true'
	assert media_reset_raw_owner_take_task(document) == none
	mut video_media := html.html_media_element_for_dom_element(video) or { panic('Video reset owner missing') }
	audio_media := html.html_media_element_for_dom_element(audio) or { panic('Audio reset owner missing') }
	media_reset_raw_owner_warm_bridge(mut runtime, video_media, '__mediaResetRawVideoWarm', false, true)!
	media_reset_raw_owner_warm_bridge(mut runtime, audio_media, '__mediaResetRawAudioWarm', true, true)!
	observation := &MediaResetRawOwnerObservation{}
	media_reset_raw_owner_observe(video, observation)
	media_reset_raw_owner_observe(audio, observation)
	// Enter loading through the real ongoing algorithm, executing its state
	// task while leaving the pending progress task for load() to discard.
	video_media.process_media_data(.ongoing)
	(media_reset_raw_owner_take_task(document) or { panic('Missing reset loading task') }).execute()
	assert runtime.evaluate_host('__mediaResetRawVideoWarm()&&__mediaResetRawAudioWarm()&&mrrVideo.networkState===2&&mrrAudio.networkState===1&&mrrVideo.readyState===1&&mrrAudio.readyState===1&&mrrVideo.currentTime===6&&mrrAudio.currentTime===6&&!mrrVideo.paused&&!mrrAudio.paused&&mrrVideo.seeking&&mrrAudio.seeking&&mrrRuns===0')! == 'true'
	assert runtime.evaluate_host('mrrOther.volume=0.5;mrrVideo.load();mrrAudio.load();mrrRuns===0&&mrrOtherRuns===0&&mrrOrder.length===0&&mrrVideo.networkState===0&&mrrAudio.networkState===0')! == 'true'
	// Only the two reset owners lose their pending media tasks. The unrelated
	// audio owner's previously queued volume task remains ahead of the resets.
	(media_reset_raw_owner_take_task(document) or { panic('Missing preserved other-owner task') }).execute()
	assert runtime.evaluate_host('mrrOtherRuns===1&&mrrOrder.join(",")==="other"&&mrrRuns===0')! == 'true'
	media_reset_raw_owner_drain(document)
	assert runtime.evaluate_host(r'
mrrRuns===4&&mrrOrder.join(",")==="other,mrr-video:abort,mrr-video:emptied,mrr-video:timeupdate,mrr-audio:abort,mrr-audio:emptied,mrr-audio:timeupdate"&&mrrScopes.join(",")==="parsed element,document,global,parsed element,document,global,created element,document,global,created element,document,global"&&mrrChecks.length===7&&mrrChecks.every(Boolean)&&mrrSaved.every(event=>event.defaultPrevented)&&mrrForm.scopeKey==="nearest form"&&mrrVideo.onabort===mrrVideoAbort&&mrrVideo.onemptied===mrrVideoEmptied&&mrrAudio.onabort===mrrAudioAbort&&mrrAudio.onemptied===mrrAudioEmptied&&window.event===undefined
')! == 'true'
	assert observation.events.len == 4
	assert observation.targets == [voidptr(video), voidptr(video), voidptr(audio), voidptr(audio)]
	for index, event in observation.events {
		media_reset_raw_owner_event(mut runtime, event, 'mrrSaved[${index}]')!
	}
	assert video_media.event_count('abort') == 1 && video_media.event_count('emptied') == 1 && video_media.event_count('timeupdate') == 1
	assert audio_media.event_count('abort') == 1 && audio_media.event_count('emptied') == 1 && audio_media.event_count('timeupdate') == 1
	assert video_media.event_count('progress') == 0 && video_media.event_count('loadedmetadata') == 0 && video_media.event_count('durationchange') == 0
	assert audio_media.event_count('loadedmetadata') == 0 && audio_media.event_count('durationchange') == 0
	// Empty(0) reflects V's existing eager resource selection. Upstream keeps
	// NoSource(3) until its separate stable-state selection task; that timing
	// boundary is deliberately outside this raw-handler slice.
	app.poll_javascript_tasks()
	assert document.get_element_by_id('mrr-result')?.text_content()? == 'raw media reset painted'
	assert video.get_attribute_value('style').contains('color') && audio.get_attribute_value('style').contains('color')
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'raw media reset painted').len > 0
	assert app.js_messages == []
	media_reset_raw_owner_balance(runtime, document, 0)
}

fn test_media_raw_reset_live_equal_attributes_prequeued_replacement_reload_cancels_pending_and_removal() {
	$if !darwin { return }
	body := r'mrrOrder.push("original-"+event.type);mrrSaved.push(event);return false;'
	attribute_body := body.replace('"', '&quot;')
	markup := media_reset_raw_owner_markup.replace('<video id="mrr-video">',
		'<video id="mrr-video" onabort="${attribute_body}" onemptied="${attribute_body}">')
	mut app, mut document, mut runtime := media_reset_raw_owner_fixture(markup, r'
globalThis.mrrVideo=document.getElementById("mrr-video");globalThis.mrrOrder=[];globalThis.mrrSaved=[];globalThis.mrrChecks=[];globalThis.mrrSource=mrrVideo.getAttribute("onabort");globalThis.mrrFirstAbort=mrrVideo.onabort;globalThis.mrrFirstEmptied=mrrVideo.onemptied;
globalThis.mrrAbortIDL=function(event){mrrOrder.push("idl-abort");mrrSaved.push(event);mrrChecks.push(this===mrrVideo&&event.isTrusted&&window.event===event&&this.networkState===0&&this.readyState===0&&this.currentTime===0&&this.paused&&!this.seeking);return false};
globalThis.mrrEmptiedIDL=function(event){mrrOrder.push("idl-emptied");mrrSaved.push(event);mrrChecks.push(this===mrrVideo&&event.isTrusted&&window.event===event&&this.networkState===0&&this.readyState===0&&this.currentTime===0&&this.paused&&!this.seeking);return false};0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	media_reset_raw_owner_probe(mut runtime, document)!
	video := document.get_element_by_id('mrr-video')?
	native_video := unsafe { &dom.EventTarget(video) }
	abort_slot := native_video.data.event_handler('abort') or { panic('Abort slot missing') }
	emptied_slot := native_video.data.event_handler('emptied') or { panic('Emptied slot missing') }
	abort_listener := abort_slot.listener or { panic('Abort listener missing') }
	emptied_listener := emptied_slot.listener or { panic('Emptied listener missing') }
	first_abort := native_video.get_current_value_of_event_handler('abort') or { panic('First abort callback missing') }
	first_emptied := native_video.get_current_value_of_event_handler('emptied') or { panic('First emptied callback missing') }
	assert runtime.evaluate_host(r'
mrrVideo.onabort=mrrAbortIDL;mrrVideo.setAttribute("onabort",mrrSource);globalThis.mrrSecondAbort=mrrVideo.onabort;
mrrVideo.onemptied=mrrEmptiedIDL;mrrVideo.setAttribute("onemptied",mrrSource);globalThis.mrrSecondEmptied=mrrVideo.onemptied;
typeof mrrSecondAbort==="function"&&mrrSecondAbort!==mrrFirstAbort&&mrrSecondAbort!==mrrAbortIDL&&mrrSecondAbort.name==="onabort"&&mrrSecondAbort.length===1&&typeof mrrSecondEmptied==="function"&&mrrSecondEmptied!==mrrFirstEmptied&&mrrSecondEmptied!==mrrEmptiedIDL&&mrrSecondEmptied.name==="onemptied"&&mrrSecondEmptied.length===1&&mrrVideo.onabort===mrrSecondAbort&&mrrVideo.onemptied===mrrSecondEmptied&&mrrOrder.length===0
')! == 'true'
	assert voidptr(native_video.data.event_handler('abort') or { panic('Replaced abort slot missing') }) == voidptr(abort_slot)
	assert voidptr(native_video.data.event_handler('emptied') or { panic('Replaced emptied slot missing') }) == voidptr(emptied_slot)
	assert voidptr(abort_slot.listener or { panic('Replaced abort listener missing') }) == voidptr(abort_listener)
	assert voidptr(emptied_slot.listener or { panic('Replaced emptied listener missing') }) == voidptr(emptied_listener)
	second_abort := native_video.get_current_value_of_event_handler('abort') or { panic('Second abort callback missing') }
	second_emptied := native_video.get_current_value_of_event_handler('emptied') or { panic('Second emptied callback missing') }
	assert voidptr(second_abort) != voidptr(first_abort) && second_abort.compiled_source_text_ == first_abort.compiled_source_text_
	assert voidptr(second_emptied) != voidptr(first_emptied) && second_emptied.compiled_source_text_ == first_emptied.compiled_source_text_
	media := html.html_media_element_for_dom_element(video) or { panic('Reentrant reset media owner missing') }
	media_reset_raw_owner_warm_bridge(mut runtime, media, '__mediaResetRawInitialWarm', true, true)!
	media_reset_raw_owner_warm_bridge(mut runtime, media, '__mediaResetRawIdleWarm', true, false)!
	assert runtime.evaluate_host('__mediaResetRawInitialWarm();mrrVideo.load();mrrOrder.length===0')! == 'true'
	queued_emptied_body := r'mrrOrder.push("reentrant-emptied");mrrSaved.push(event);mrrChecks.push(event.isTrusted&&this===mrrVideo&&this.networkState===0&&this.readyState===0&&this.currentTime===0&&this.paused&&!this.seeking&&window.event===event&&__mediaResetRawOwnerContext());this.onemptied=mrrEmptiedIDL;document.getElementById("mrr-result").textContent="reentrant media reset painted";return false;'
	queued_abort_body := r'mrrOrder.push("replacement-abort");mrrSaved.push(event);mrrChecks.push(event.isTrusted&&this===mrrVideo&&this.networkState===0&&this.currentTime===0&&window.event===event&&__mediaResetRawOwnerContext());this.setAttribute("onemptied",mrrQueuedEmptiedBody);void this.paused;this.onabort=mrrAbortIDL;mrrChecks.push(__mediaResetRawIdleWarm()&&this.load()===undefined&&mrrSaved.length===1);return false;'
	assert runtime.evaluate_host('globalThis.mrrQueuedEmptiedBody=${json2.encode(queued_emptied_body)};mrrVideo.setAttribute("onabort",${json2.encode(queued_abort_body)});mrrVideo.paused&&mrrOrder.length===0')! == 'true'
	assert abort_slot.value.kind == .string && abort_slot.value.string_data == queued_abort_body
	(media_reset_raw_owner_take_task(document) or { panic('Missing replacement abort task') }).execute()
	assert runtime.evaluate_host('mrrOrder.join(",")==="replacement-abort"&&mrrSaved.length===1&&mrrVideo.onabort===mrrAbortIDL')! == 'true'
	assert emptied_slot.value.kind == .string && emptied_slot.value.string_data == queued_emptied_body
	// Reentrant actual load removes the old pending emptied/timeupdate tasks.
	// The fresh idle reset queues a new abort/emptied pair, using latest slots.
	media_reset_raw_owner_drain(document)
	assert media_reset_raw_owner_take_task(document) == none
	assert runtime.evaluate_host('mrrOrder.join(",")==="replacement-abort,idl-abort,reentrant-emptied"&&mrrSaved.length===3&&mrrSaved.every(event=>event.isTrusted&&event.defaultPrevented)&&mrrChecks.length===4&&mrrChecks.every(Boolean)&&mrrVideo.onabort===mrrAbortIDL&&mrrVideo.onemptied===mrrEmptiedIDL&&window.event===undefined')! == 'true'
	assert voidptr(emptied_slot.listener or { panic('Reentrant emptied listener missing') }) == voidptr(emptied_listener)
	assert media.event_count('abort') == 2 && media.event_count('emptied') == 1 && media.event_count('timeupdate') == 0
	assert runtime.evaluate_host('__mediaResetRawIdleWarm();mrrVideo.load();mrrVideo.removeAttribute("onabort");mrrVideo.removeAttribute("onemptied");mrrVideo.onabort===null&&mrrVideo.onemptied===null&&mrrOrder.length===3')! == 'true'
	assert !native_video.data.has_event_handler('abort') && !native_video.data.has_event_handler('emptied')
	assert video.get_attribute('onabort') == none && video.get_attribute('onemptied') == none
	media_reset_raw_owner_drain(document)
	assert runtime.evaluate_host('mrrOrder.length===3&&mrrSaved.length===3')! == 'true'
	assert runtime.evaluate_host('mrrVideo.onabort=mrrAbortIDL;mrrVideo.onemptied=mrrEmptiedIDL;mrrVideo.removeAttribute("onabort");mrrVideo.removeAttribute("onemptied");__mediaResetRawIdleWarm();mrrVideo.load();mrrVideo.onabort===mrrAbortIDL&&mrrVideo.onemptied===mrrEmptiedIDL&&mrrOrder.length===3')! == 'true'
	media_reset_raw_owner_drain(document)
	assert runtime.evaluate_host('mrrOrder.join(",")==="replacement-abort,idl-abort,reentrant-emptied,idl-abort,idl-emptied"&&mrrChecks.length===6&&mrrChecks.every(Boolean)&&mrrSaved.length===5&&mrrSaved.every(event=>event.isTrusted&&event.defaultPrevented)&&mrrVideo.onabort===mrrAbortIDL&&mrrVideo.onemptied===mrrEmptiedIDL&&window.event===undefined')! == 'true'
	assert native_video.event_listener_list().len == 2
	assert media.event_count('abort') == 4 && media.event_count('emptied') == 3 && media.event_count('timeupdate') == 0
	for index in 0 .. 5 {
		event := runtime.native_event(runtime.evaluate_host_value('mrrSaved[${index}]')!)!
		media_reset_raw_owner_event(mut runtime, event, 'mrrSaved[${index}]')!
	}
	app.poll_javascript_tasks()
	assert document.get_element_by_id('mrr-result')?.text_content()? == 'reentrant media reset painted'
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'reentrant media reset painted').len > 0
	assert app.js_messages == []
	media_reset_raw_owner_balance(runtime, document, 0)
}

fn test_media_raw_reset_scripting_gate_strict_original_exception_and_later_owner_listener() {
	$if !darwin { return }
	mut app, mut document, mut runtime := media_reset_raw_owner_fixture(media_reset_raw_owner_markup, r'
globalThis.mrrVideo=document.getElementById("mrr-video");globalThis.mrrRuns=0;globalThis.mrrEmptiedRuns=0;globalThis.mrrChecks=[];globalThis.mrrSaved=[];globalThis.mrrReason={original:true};globalThis.mrrOrder=[];mrrVideo.event={sentinel:true};document.event={sentinel:true};0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	media_reset_raw_owner_probe(mut runtime, document)!
	video := document.get_element_by_id('mrr-video')?
	native_video := unsafe { &dom.EventTarget(video) }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	media := html.html_media_element_for_dom_element(video) or { panic('Gated reset media owner missing') }
	media_reset_raw_owner_warm_bridge(mut runtime, media, '__mediaResetRawGatedWarm', true, true)!
	media_reset_raw_owner_warm_bridge(mut runtime, media, '__mediaResetRawGatedIdle', true, false)!
	body := r'"use strict";mrrRuns++;mrrOrder.push("strict-abort");mrrSaved.push(event);mrrChecks.push(arguments.length===1&&event===arguments[0]&&this===mrrVideo&&event.target===mrrVideo&&event.currentTarget===mrrVideo&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event&&this.networkState===0&&this.readyState===0&&this.currentTime===0&&this.paused&&!this.seeking&&Number.isNaN(this.duration)&&__mediaResetRawOwnerContext());try{void arguments.callee;mrrChecks.push(false)}catch(error){mrrChecks.push(error instanceof TypeError)}this.onabort=null;globalThis.mrrLiveName=onabort;throw mrrReason;'
	emptied_body := r'mrrEmptiedRuns++;mrrOrder.push("raw-emptied");mrrSaved.push(event);mrrChecks.push(event.isTrusted&&this===mrrVideo&&window.event===event&&this.networkState===0&&this.readyState===0&&this.currentTime===0&&this.paused&&!this.seeking&&Number.isNaN(this.duration)&&__mediaResetRawOwnerContext());return false;'
	assert runtime.evaluate_host('mrrVideo.setAttribute("onabort",${json2.encode(body)});mrrVideo.setAttribute("onemptied",${json2.encode(emptied_body)});mrrVideo.paused')! == 'true'
	abort_slot := native_video.data.event_handler('abort') or { panic('Strict abort slot missing') }
	emptied_slot := native_video.data.event_handler('emptied') or { panic('Raw emptied slot missing') }
	mut owner := app.page_model
	owner.set_is_scripting_enabled(false)
	assert runtime.evaluate_host('__mediaResetRawGatedWarm();mrrVideo.load();mrrVideo.onabort===null&&mrrVideo.onemptied===null&&mrrRuns===0&&mrrEmptiedRuns===0')! == 'true'
	media_reset_raw_owner_drain(document)
	assert abort_slot.value.kind == .string && abort_slot.value.string_data == body
	assert emptied_slot.value.kind == .string && emptied_slot.value.string_data == emptied_body
	assert media.event_count('abort') == 1 && media.event_count('emptied') == 1 && media.event_count('timeupdate') == 1
	assert runtime.evaluate_host('mrrRuns===0&&mrrEmptiedRuns===0&&mrrSaved.length===0&&mrrOrder.length===0')! == 'true'
	media_reset_raw_owner_balance(runtime, document, 0)
	owner.set_is_scripting_enabled(true)
	assert runtime.evaluate_host(r'
globalThis.mrrStrict=mrrVideo.onabort;globalThis.mrrEmptied=mrrVideo.onemptied;
mrrVideo.addEventListener("abort",function(event){mrrOrder.push("later-abort");globalThis.mrrLater=this===mrrVideo&&event.currentTarget===mrrVideo&&event.isTrusted&&!event.defaultPrevented&&window.event===event&&this.networkState===0&&this.readyState===0&&this.currentTime===0;document.getElementById("mrr-result").textContent="later native abort listener"});typeof mrrStrict==="function"&&mrrStrict.name==="onabort"&&mrrStrict.length===1&&mrrVideo.onabort===mrrStrict&&typeof mrrEmptied==="function"&&mrrEmptied.name==="onemptied"&&mrrVideo.onemptied===mrrEmptied&&mrrRuns===0
')! == 'true'
	strict_callback := native_video.get_current_value_of_event_handler('abort') or { panic('Strict abort callback missing') }
	assert strict_callback.compiled_source_text_ == 'function onabort(event) {\n${body}\n}'
	assert runtime.javascript_event_handler(native_video, 'abort')! == runtime.evaluate_host_value('mrrStrict')!
	assert runtime.evaluate_host('__mediaResetRawGatedIdle();mrrVideo.load();mrrOrder.length===0')! == 'true'
	(media_reset_raw_owner_take_task(document) or { panic('Missing strict abort task') }).execute()
	assert runtime.evaluate_host('mrrOrder.join(",")==="strict-abort,later-abort"&&mrrRuns===1&&mrrEmptiedRuns===0&&mrrLiveName===null&&mrrVideo.onabort===null&&mrrLater&&mrrChecks.length===2&&mrrChecks.every(Boolean)&&window.event===undefined')! == 'true'
	assert !native_video.data.has_event_handler('abort') && native_video.data.has_event_handler('emptied')
	assert video.get_attribute_value('onabort') == body && video.get_attribute_value('onemptied') == emptied_body
	assert settings.realm().reported_exceptions.len == 1
	reported := settings.realm().reported_exceptions[0].value.as_webidl_value()!
	assert runtime.actual_webidl_value(reported)! == runtime.evaluate_host_value('mrrReason')!
	// Emptied remains a separate real native task after the throwing handler.
	(media_reset_raw_owner_take_task(document) or { panic('Missing later emptied task') }).execute()
	assert media_reset_raw_owner_take_task(document) == none
	assert runtime.evaluate_host('mrrRuns===1&&mrrEmptiedRuns===1&&mrrChecks.length===3&&mrrChecks.every(Boolean)&&mrrVideo.onemptied===mrrEmptied&&mrrSaved.length===2&&!mrrSaved[0].defaultPrevented&&mrrSaved[1].defaultPrevented&&mrrOrder.join(",")==="strict-abort,later-abort,raw-emptied"&&window.event===undefined')! == 'true'
	assert media.event_count('abort') == 2 && media.event_count('emptied') == 2 && media.event_count('timeupdate') == 1
	for index in 0 .. 2 {
		event := runtime.native_event(runtime.evaluate_host_value('mrrSaved[${index}]')!)!
		media_reset_raw_owner_event(mut runtime, event, 'mrrSaved[${index}]')!
	}
	app.poll_javascript_tasks()
	assert document.get_element_by_id('mrr-result')?.text_content()? == 'later native abort listener'
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'later native abort listener').len > 0
	assert app.js_messages == []
	media_reset_raw_owner_balance(runtime, document, 1)
}

