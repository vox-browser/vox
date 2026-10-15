module main

import browserjs
import dom
import html
import json2
import page
import time

const media_seek_raw_owner_markup = '<!doctype html><style>
html,body{margin:0}#msk-video{display:block;width:180px;height:60px}
#msk-result{position:absolute;top:100px;left:0}
</style><form id="msk-form"><video id="msk-video"></video></form><div id="msk-result">waiting</div>'

@[heap]
struct MediaSeekRawOwnerObservation {
mut:
	events []&dom.Event
	targets []voidptr
}

@[heap]
struct MediaSeekRawOwnerClock {
mut:
	position f64 = 2
	targets []f64
	modes []html.MediaPlaybackSeekMode
}

fn media_seek_raw_owner_fixture(markup string, source string) !(&BrowserApp, &dom.Document, &browserjs.Runtime) {
	mut owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{
		value: 'https://media-seek-raw-owner.example.test/'
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

fn media_seek_raw_owner_take_task(document &dom.Document) ?&html.Task {
	mut queue := html.main_thread_event_loop().task_queue()
	return queue.take_first_runnable_matching(fn [document] (task &html.Task) bool {
		owner := task.document() or { return false }
		return task.source() == .media_element && voidptr(owner) == voidptr(document)
	})
}

fn media_seek_raw_owner_drain(document &dom.Document) {
	mut count := 0
	for {
		task := media_seek_raw_owner_take_task(document) or { break }
		count++
		assert count < 100
		task.execute()
	}
}

fn media_seek_raw_owner_probe(mut runtime browserjs.Runtime, document &dom.Document) ! {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	handle := voidptr(&runtime)
	actual_true := runtime.evaluate_host_value('true')!
	runtime.define_value_host_function('__mediaSeekRawOwnerContext', fn [settings, handle, actual_true] (_ voidptr, args []voidptr) !voidptr {
		owner := unsafe { &browserjs.Runtime(handle) }
		assert args.len == 0
		assert settings.realm().script_execution_depth > 0 && settings.realm().callback_execution_depth > 0
		assert owner.libjs_vm().has_running_execution_context()
		assert voidptr(html.current_principal_settings_object()) == voidptr(settings)
		assert voidptr(html.incumbent_settings_object()) == voidptr(settings)
		return actual_true
	})!
}

fn media_seek_raw_owner_observe(element &dom.Element, observation &MediaSeekRawOwnerObservation) {
	handle := voidptr(observation)
	callback := &dom.CallbackType{
		handle_event: fn [handle] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut saved := unsafe { &MediaSeekRawOwnerObservation(handle) }
			assert event.type_name() in ['seeking', 'seeked']
			assert event.interface_ == .event && event.is_trusted()
			// The handler algorithm applies exact false to the canceled flag,
			// including native seek events whose cancelable flag is false.
			assert !event.bubbles() && !event.cancelable() && event.default_prevented()
			saved.events << event
			saved.targets << voidptr(event.target() or { panic('Native seek event needs its owner') })
			return dom.js_undefined()
		}
	}
	for name in ['seeking', 'seeked'] {
		unsafe { &dom.EventTarget(element) }.add_event_listener_without_options(name, dom.IDLEventListener.create(callback))
	}
}

fn media_seek_raw_owner_event(mut runtime browserjs.Runtime, event &dom.Event, expression string) ! {
	wrapper := runtime.evaluate_host_value(expression)!
	assert voidptr(runtime.native_event(wrapper)!) == voidptr(event)
	assert runtime.javascript_event(event)! == wrapper
	assert event.is_trusted() && event.current_target() == none && event.event_phase() == 0
	assert runtime.evaluate_host('${expression}.currentTarget===null&&${expression}.eventPhase===Event.NONE&&window.event===undefined')! == 'true'
}

fn media_seek_raw_owner_balance(runtime &browserjs.Runtime, document &dom.Document, exceptions int) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == exceptions
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn media_seek_raw_owner_prepare(mut runtime browserjs.Runtime, element &dom.Element, alias string) !(&html.HTMLMediaElement, &MediaSeekRawOwnerClock) {
	mut media := html.html_media_element_for_dom_element(element) or { return error('Missing native seek owner') }
	// The in-process response adapter supplies metadata and the translated
	// cached seekable range without performing a network request or decoding.
	media.set_fetch_hook(fn (_ dom.URL, _ u64) !html.MediaResourceResponse {
		return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 20, buffered_end: 20 }
	})
	assert runtime.evaluate_host('${alias}.src="/controlled-seek.mp4";${alias}.load();${alias}.readyState===4')! == 'true'
	media_seek_raw_owner_drain(element.document())
	media.set_ready_state(.have_metadata)
	clock := &MediaSeekRawOwnerClock{}
	media.set_playback_manager_hooks(html.MediaPlaybackManagerHooks{
		current_time: fn [clock] () f64 { return clock.position }
		seek: fn [clock] (value f64, mode html.MediaPlaybackSeekMode) {
			mut state := unsafe { &MediaSeekRawOwnerClock(clock) }
			state.targets << value
			state.modes << mode
			state.position = value
		}
	})
	media.set_official_playback_position(2)
	assert media.ready_state() == .have_metadata && media.paused() && !media.seeking()
	assert media.seekable().length() == 1 && media.seekable().start(0)! == 0 && media.seekable().end(0)! == 20
	return media, clock
}

fn media_seek_raw_owner_finish_bridge(mut runtime browserjs.Runtime, media &html.HTMLMediaElement, name string) ! {
	media_handle := voidptr(media)
	actual_true := runtime.evaluate_host_value('true')!
	runtime.define_value_host_function(name, fn [media_handle, actual_true] (_ voidptr, args []voidptr) !voidptr {
		assert args.len == 0
		mut current_media := unsafe { &html.HTMLMediaElement(media_handle) }
		assert current_media.seeking()
		current_media.finish_seeking_element()
		assert !current_media.seeking()
		return actual_true
	})!
}

fn test_media_raw_seeking_seeked_parsed_created_scopes_trusted_events_and_native_finish_order() {
	$if !darwin { return }
	body := r'mskRuns++;mskOrder.push(this.id+":"+event.type);mskScopes.push(scopeKey);delete this.scopeKey;mskScopes.push(scopeKey);delete document.scopeKey;mskScopes.push(scopeKey);document.scopeKey="document";this.scopeKey=this.id==="msk-video"?"parsed element":"created element";mskSaved.push(event);mskChecks.push(arguments.length===1&&event===arguments[0]&&(this===mskVideo||this===mskAudio)&&event.target===this&&event.currentTarget===this&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event&&document===mskDocument&&getElementById("msk-result")===mskResult&&seeking===(event.type==="seeking")&&currentTime===6&&paused===true&&__mediaSeekRawOwnerContext());getElementById("msk-result").textContent="raw native seek painted";this.style.color="rgb(0,128,0)";return false;'
	attribute_body := body.replace('"', '&quot;')
	markup := media_seek_raw_owner_markup.replace('<video id="msk-video">',
		'<video id="msk-video" onseeking="${attribute_body}" onseeked="${attribute_body}">')
	mut app, mut document, mut runtime := media_seek_raw_owner_fixture(markup, r'
globalThis.mskVideo=document.getElementById("msk-video");globalThis.mskDocument=document;globalThis.mskResult=document.getElementById("msk-result");globalThis.mskForm=document.getElementById("msk-form");
globalThis.mskRuns=0;globalThis.mskOrder=[];globalThis.mskScopes=[];globalThis.mskSaved=[];globalThis.mskChecks=[];globalThis.scopeKey="global";
document.scopeKey="document";mskForm.scopeKey="nearest form";mskVideo.scopeKey="parsed element";mskVideo.event={sentinel:true};document.event={sentinel:true};
globalThis.mskAudio=document.createElement("audio");mskAudio.id="msk-audio";mskAudio.setAttribute("onseeking",mskVideo.getAttribute("onseeking"));mskAudio.setAttribute("onseeked",mskVideo.getAttribute("onseeked"));document.body.appendChild(mskAudio);mskAudio.scopeKey="created element";void mskAudio.paused;
for(var mskElement of [mskVideo,mskAudio])mskElement.addEventListener("timeupdate",function(event){mskOrder.push(this.id+":"+event.type);mskChecks.push(event instanceof Event&&event.isTrusted&&event.target===this&&event.currentTarget===this&&!event.bubbles&&!event.cancelable&&!event.defaultPrevented&&!this.seeking&&this.currentTime===6&&window.event===event)});0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	media_seek_raw_owner_probe(mut runtime, document)!
	video := document.get_element_by_id('msk-video')?
	audio := document.get_element_by_id('msk-audio')?
	native_video := unsafe { &dom.EventTarget(video) }
	native_audio := unsafe { &dom.EventTarget(audio) }
	for target in [native_video, native_audio] {
		for name in ['seeking', 'seeked'] {
			slot := target.data.event_handler(name) or { panic('Raw seek slot missing') }
			assert slot.value.kind == .string && slot.value.string_data == body
		}
	}
	assert runtime.evaluate_host(r'
globalThis.mskVideoSeeking=mskVideo.onseeking;globalThis.mskVideoSeeked=mskVideo.onseeked;globalThis.mskAudioSeeking=mskAudio.onseeking;globalThis.mskAudioSeeked=mskAudio.onseeked;
[mskVideoSeeking,mskVideoSeeked,mskAudioSeeking,mskAudioSeeked].every(value=>typeof value==="function"&&value.length===1)&&mskVideoSeeking.name==="onseeking"&&mskAudioSeeking.name==="onseeking"&&mskVideoSeeked.name==="onseeked"&&mskAudioSeeked.name==="onseeked"&&new Set([mskVideoSeeking,mskVideoSeeked,mskAudioSeeking,mskAudioSeeked]).size===4&&mskVideo.onseeking===mskVideoSeeking&&mskVideo.onseeked===mskVideoSeeked&&mskAudio.onseeking===mskAudioSeeking&&mskAudio.onseeked===mskAudioSeeked&&!Object.hasOwn(mskVideo,"onseeking")&&!Object.hasOwn(mskAudio,"onseeked")&&mskRuns===0
')! == 'true'
	for target in [native_video, native_audio] {
		alias := if voidptr(target) == voidptr(native_video) { 'mskVideo' } else { 'mskAudio' }
		for name in ['seeking', 'seeked'] {
			callback := target.get_current_value_of_event_handler(name) or { panic('Cached seek callback missing') }
			assert callback.compiled_source_text_ == 'function on${name}(event) {\n${body}\n}'
			assert runtime.javascript_event_handler(target, name)! == runtime.evaluate_host_value('${alias}.on${name}')!
		}
	}
	observation := &MediaSeekRawOwnerObservation{}
	media_seek_raw_owner_observe(video, observation)
	media_seek_raw_owner_observe(audio, observation)
	video_media, video_clock := media_seek_raw_owner_prepare(mut runtime, video, 'mskVideo')!
	audio_media, audio_clock := media_seek_raw_owner_prepare(mut runtime, audio, 'mskAudio')!
	media_seek_raw_owner_finish_bridge(mut runtime, video_media, '__mediaSeekRawVideoFinish')!
	media_seek_raw_owner_finish_bridge(mut runtime, audio_media, '__mediaSeekRawAudioFinish')!
	assert runtime.evaluate_host('mskVideo.currentTime=6;mskAudio.fastSeek(6);mskVideo.seeking&&mskAudio.seeking&&mskVideo.currentTime===6&&mskAudio.currentTime===6&&mskRuns===0&&mskOrder.length===0')! == 'true'
	assert video_clock.targets == [6.0] && video_clock.modes == [.accurate]
	assert audio_clock.targets == [6.0] && audio_clock.modes == [.fast_after]
	(media_seek_raw_owner_take_task(document) or { panic('Missing parsed seeking task') }).execute()
	assert runtime.evaluate_host('mskRuns===1&&mskOrder.join(",")==="msk-video:seeking"&&mskVideo.seeking&&mskAudio.seeking')! == 'true'
	(media_seek_raw_owner_take_task(document) or { panic('Missing created seeking task') }).execute()
	assert media_seek_raw_owner_take_task(document) == none
	assert runtime.evaluate_host('mskRuns===2&&mskOrder.join(",")==="msk-video:seeking,msk-audio:seeking"&&mskVideo.seeking&&mskAudio.seeking')! == 'true'
	// The controlled manager completes only after each actual seeking task.
	// Completion clears the flag now and queues timeupdate before seeked.
	assert runtime.evaluate_host('__mediaSeekRawVideoFinish()&&__mediaSeekRawAudioFinish()&&!mskVideo.seeking&&!mskAudio.seeking&&mskRuns===2&&mskOrder.length===2')! == 'true'
	media_seek_raw_owner_drain(document)
	assert runtime.evaluate_host(r'
mskRuns===4&&mskOrder.join(",")==="msk-video:seeking,msk-audio:seeking,msk-video:timeupdate,msk-video:seeked,msk-audio:timeupdate,msk-audio:seeked"&&mskScopes.join(",")==="parsed element,document,global,created element,document,global,parsed element,document,global,created element,document,global"&&mskChecks.length===6&&mskChecks.every(Boolean)&&mskSaved.every(event=>event.defaultPrevented)&&mskForm.scopeKey==="nearest form"&&mskVideo.onseeking===mskVideoSeeking&&mskVideo.onseeked===mskVideoSeeked&&mskAudio.onseeking===mskAudioSeeking&&mskAudio.onseeked===mskAudioSeeked&&window.event===undefined
')! == 'true'
	assert observation.events.len == 4
	assert observation.targets == [voidptr(video), voidptr(audio), voidptr(video), voidptr(audio)]
	for index, event in observation.events {
		media_seek_raw_owner_event(mut runtime, event, 'mskSaved[${index}]')!
	}
	assert video_media.event_count('seeking') == 1 && video_media.event_count('seeked') == 1 && video_media.event_count('timeupdate') == 1
	assert audio_media.event_count('seeking') == 1 && audio_media.event_count('seeked') == 1 && audio_media.event_count('timeupdate') == 1
	app.poll_javascript_tasks()
	assert document.get_element_by_id('msk-result')?.text_content()? == 'raw native seek painted'
	assert video.get_attribute_value('style').contains('color') && audio.get_attribute_value('style').contains('color')
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'raw native seek painted').len > 0
	assert app.js_messages == []
	media_seek_raw_owner_balance(runtime, document, 0)
}

fn test_media_raw_seek_live_equal_attributes_prequeued_replacement_equal_target_reentry_and_removal() {
	$if !darwin { return }
	body := r'mskOrder.push("original-"+event.type);mskSaved.push(event);return false;'
	attribute_body := body.replace('"', '&quot;')
	markup := media_seek_raw_owner_markup.replace('<video id="msk-video">',
		'<video id="msk-video" onseeking="${attribute_body}" onseeked="${attribute_body}">')
	mut app, mut document, mut runtime := media_seek_raw_owner_fixture(markup, r'
globalThis.mskVideo=document.getElementById("msk-video");globalThis.mskOrder=[];globalThis.mskSaved=[];globalThis.mskChecks=[];globalThis.mskSource=mskVideo.getAttribute("onseeking");globalThis.mskFirstSeeking=mskVideo.onseeking;globalThis.mskFirstSeeked=mskVideo.onseeked;
globalThis.mskSeekingIDL=function(event){mskOrder.push("idl-seeking");mskSaved.push(event);mskChecks.push(this===mskVideo&&event.isTrusted&&window.event===event&&this.seeking&&this.currentTime===6);return false};
globalThis.mskSeekedIDL=function(event){mskOrder.push("idl-seeked");mskSaved.push(event);mskChecks.push(this===mskVideo&&event.isTrusted&&window.event===event&&!this.seeking&&this.currentTime===6);return false};
mskVideo.addEventListener("timeupdate",function(event){mskOrder.push("timeupdate");mskChecks.push(this===mskVideo&&event.isTrusted&&!event.defaultPrevented&&!this.seeking&&this.currentTime===6&&window.event===event)});0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	media_seek_raw_owner_probe(mut runtime, document)!
	video := document.get_element_by_id('msk-video')?
	native_video := unsafe { &dom.EventTarget(video) }
	seeking_slot := native_video.data.event_handler('seeking') or { panic('Seeking slot missing') }
	seeked_slot := native_video.data.event_handler('seeked') or { panic('Seeked slot missing') }
	seeking_listener := seeking_slot.listener or { panic('Seeking listener missing') }
	seeked_listener := seeked_slot.listener or { panic('Seeked listener missing') }
	first_seeking := native_video.get_current_value_of_event_handler('seeking') or { panic('First seeking callback missing') }
	first_seeked := native_video.get_current_value_of_event_handler('seeked') or { panic('First seeked callback missing') }
	assert runtime.evaluate_host(r'
mskVideo.onseeking=mskSeekingIDL;mskVideo.setAttribute("onseeking",mskSource);globalThis.mskSecondSeeking=mskVideo.onseeking;
mskVideo.onseeked=mskSeekedIDL;mskVideo.setAttribute("onseeked",mskSource);globalThis.mskSecondSeeked=mskVideo.onseeked;
typeof mskSecondSeeking==="function"&&mskSecondSeeking!==mskFirstSeeking&&mskSecondSeeking!==mskSeekingIDL&&mskSecondSeeking.name==="onseeking"&&mskSecondSeeking.length===1&&typeof mskSecondSeeked==="function"&&mskSecondSeeked!==mskFirstSeeked&&mskSecondSeeked!==mskSeekedIDL&&mskSecondSeeked.name==="onseeked"&&mskSecondSeeked.length===1&&mskVideo.onseeking===mskSecondSeeking&&mskVideo.onseeked===mskSecondSeeked&&mskOrder.length===0
')! == 'true'
	assert voidptr(native_video.data.event_handler('seeking') or { panic('Replaced seeking slot missing') }) == voidptr(seeking_slot)
	assert voidptr(native_video.data.event_handler('seeked') or { panic('Replaced seeked slot missing') }) == voidptr(seeked_slot)
	assert voidptr(seeking_slot.listener or { panic('Replaced seeking listener missing') }) == voidptr(seeking_listener)
	assert voidptr(seeked_slot.listener or { panic('Replaced seeked listener missing') }) == voidptr(seeked_listener)
	second_seeking := native_video.get_current_value_of_event_handler('seeking') or { panic('Second seeking callback missing') }
	second_seeked := native_video.get_current_value_of_event_handler('seeked') or { panic('Second seeked callback missing') }
	assert voidptr(second_seeking) != voidptr(first_seeking) && second_seeking.compiled_source_text_ == first_seeking.compiled_source_text_
	assert voidptr(second_seeked) != voidptr(first_seeked) && second_seeked.compiled_source_text_ == first_seeked.compiled_source_text_
	media, clock := media_seek_raw_owner_prepare(mut runtime, video, 'mskVideo')!
	media_seek_raw_owner_finish_bridge(mut runtime, media, '__mediaSeekRawFinish')!
	assert runtime.evaluate_host('mskVideo.currentTime=6;mskVideo.seeking&&mskOrder.length===0')! == 'true'
	queued_seeked_body := r'mskOrder.push("replacement-seeked");mskSaved.push(event);mskChecks.push(event.isTrusted&&this===mskVideo&&!this.seeking&&this.currentTime===6&&window.event===event&&__mediaSeekRawOwnerContext());this.onseeked=mskSeekedIDL;document.getElementById("msk-result").textContent="reentrant native seek painted";return false;'
	queued_seeking_body := r'mskOrder.push("replacement-seeking");mskSaved.push(event);mskChecks.push(event.isTrusted&&this===mskVideo&&this.seeking&&this.currentTime===6&&window.event===event&&__mediaSeekRawOwnerContext());this.setAttribute("onseeked",mskQueuedSeekedBody);void this.paused;this.fastSeek(6);mskChecks.push(mskSaved.length===1&&this.seeking);this.onseeking=mskSeekingIDL;return false;'
	assert runtime.evaluate_host('globalThis.mskQueuedSeekedBody=${json2.encode(queued_seeked_body)};mskVideo.setAttribute("onseeking",${json2.encode(queued_seeking_body)});mskVideo.seeking&&mskOrder.length===0')! == 'true'
	assert seeking_slot.value.kind == .string && seeking_slot.value.string_data == queued_seeking_body
	(media_seek_raw_owner_take_task(document) or { panic('Missing replacement seeking task') }).execute()
	assert runtime.evaluate_host('mskOrder.join(",")==="replacement-seeking"&&mskSaved.length===1&&mskVideo.seeking')! == 'true'
	assert clock.targets == [6.0, 6.0] && clock.modes == [.accurate, .accurate]
	// The equal-target fastSeek still queues a real seeking event. Its IDL
	// replacement is read at delivery, with no eager dispatch during reentry.
	media_seek_raw_owner_drain(document)
	assert runtime.evaluate_host('mskOrder.join(",")==="replacement-seeking,idl-seeking"&&mskSaved.length===2&&mskVideo.seeking&&mskVideo.onseeking===mskSeekingIDL')! == 'true'
	assert seeked_slot.value.kind == .string && seeked_slot.value.string_data == queued_seeked_body
	assert runtime.evaluate_host('__mediaSeekRawFinish()&&!mskVideo.seeking&&mskOrder.length===2')! == 'true'
	media_seek_raw_owner_drain(document)
	assert runtime.evaluate_host('mskOrder.join(",")==="replacement-seeking,idl-seeking,timeupdate,replacement-seeked"&&mskSaved.length===3&&mskSaved.every(event=>event.isTrusted&&event.defaultPrevented)&&mskChecks.length===5&&mskChecks.every(Boolean)&&mskVideo.onseeking===mskSeekingIDL&&mskVideo.onseeked===mskSeekedIDL&&window.event===undefined')! == 'true'
	assert voidptr(seeked_slot.listener or { panic('Reentrant seeked listener missing') }) == voidptr(seeked_listener)
	assert media.event_count('seeking') == 2 && media.event_count('seeked') == 1 && media.event_count('timeupdate') == 1
	// Present attribute removal clears the IDL value before queued seeking and
	// completion delivery. The ordinary timeupdate listener continues to run.
	assert runtime.evaluate_host('mskVideo.fastSeek(6);mskVideo.removeAttribute("onseeking");mskVideo.removeAttribute("onseeked");mskVideo.onseeking===null&&mskVideo.onseeked===null&&mskVideo.seeking')! == 'true'
	assert !native_video.data.has_event_handler('seeking') && !native_video.data.has_event_handler('seeked')
	assert video.get_attribute('onseeking') == none && video.get_attribute('onseeked') == none
	media_seek_raw_owner_drain(document)
	assert runtime.evaluate_host('__mediaSeekRawFinish()&&!mskVideo.seeking&&mskOrder.length===4')! == 'true'
	media_seek_raw_owner_drain(document)
	assert runtime.evaluate_host('mskOrder.join(",")==="replacement-seeking,idl-seeking,timeupdate,replacement-seeked,timeupdate"&&mskSaved.length===3')! == 'true'
	// An absent attribute removal preserves later IDL callbacks on a real seek.
	assert runtime.evaluate_host('mskVideo.onseeking=mskSeekingIDL;mskVideo.onseeked=mskSeekedIDL;mskVideo.removeAttribute("onseeking");mskVideo.removeAttribute("onseeked");mskVideo.currentTime=6;mskVideo.onseeking===mskSeekingIDL&&mskVideo.onseeked===mskSeekedIDL&&mskVideo.seeking&&mskOrder.length===5')! == 'true'
	media_seek_raw_owner_drain(document)
	assert runtime.evaluate_host('__mediaSeekRawFinish()&&!mskVideo.seeking&&mskOrder.length===6')! == 'true'
	media_seek_raw_owner_drain(document)
	assert runtime.evaluate_host('mskOrder.join(",")==="replacement-seeking,idl-seeking,timeupdate,replacement-seeked,timeupdate,idl-seeking,timeupdate,idl-seeked"&&mskChecks.length===9&&mskChecks.every(Boolean)&&mskSaved.length===5&&mskSaved.every(event=>event.isTrusted&&event.defaultPrevented)&&mskVideo.onseeking===mskSeekingIDL&&mskVideo.onseeked===mskSeekedIDL&&window.event===undefined')! == 'true'
	assert native_video.event_listener_list().len == 3
	assert media.event_count('seeking') == 4 && media.event_count('seeked') == 3 && media.event_count('timeupdate') == 3
	assert clock.targets == [6.0, 6.0, 6.0, 6.0] && clock.modes == [.accurate, .accurate, .accurate, .accurate]
	for index in 0 .. 5 {
		event := runtime.native_event(runtime.evaluate_host_value('mskSaved[${index}]')!)!
		media_seek_raw_owner_event(mut runtime, event, 'mskSaved[${index}]')!
	}
	app.poll_javascript_tasks()
	assert document.get_element_by_id('msk-result')?.text_content()? == 'reentrant native seek painted'
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'reentrant native seek painted').len > 0
	assert app.js_messages == []
	media_seek_raw_owner_balance(runtime, document, 0)
}

fn test_media_raw_seek_source_empty_negatives_scripting_gate_strict_exception_and_later_owner_listener() {
	$if !darwin { return }
	mut app, mut document, mut runtime := media_seek_raw_owner_fixture(media_seek_raw_owner_markup, r'
globalThis.mskVideo=document.getElementById("msk-video");globalThis.mskRuns=0;globalThis.mskSeekedRuns=0;globalThis.mskChecks=[];globalThis.mskSaved=[];globalThis.mskReason={original:true};globalThis.mskOrder=[];globalThis.mskEmptyRuns=0;globalThis.mskConversionReason={conversion:true};mskVideo.event={sentinel:true};document.event={sentinel:true};
globalThis.mskEmpty=document.createElement("audio");mskEmpty.id="msk-empty";document.body.appendChild(mskEmpty);mskEmpty.setAttribute("onseeking","mskEmptyRuns++;return false;");mskEmpty.setAttribute("onseeked","mskEmptyRuns++;return false;");void mskEmpty.paused;0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	media_seek_raw_owner_probe(mut runtime, document)!
	video := document.get_element_by_id('msk-video')?
	empty := document.get_element_by_id('msk-empty')?
	native_video := unsafe { &dom.EventTarget(video) }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	// Without metadata the currentTime setter changes only the default start;
	// fastSeek and rejected restricted-double conversions queue no seek event.
	assert runtime.evaluate_host(r'(()=>{
mskEmpty.currentTime=5;mskEmpty.fastSeek(6);
if(mskEmpty.currentTime!==5||mskEmpty.readyState!==0||mskEmpty.seeking||mskEmptyRuns!==0)return false;
for(const value of [undefined,NaN,Infinity,-Infinity,1n,Symbol()]){
try{mskEmpty.currentTime=value;return false}catch(error){if(!(error instanceof TypeError))return false}
try{mskEmpty.fastSeek(value);return false}catch(error){if(!(error instanceof TypeError))return false}
}
for(const setter of [value=>{mskEmpty.currentTime=value},value=>mskEmpty.fastSeek(value)]){
try{setter({[Symbol.toPrimitive](){throw mskConversionReason}});return false}catch(error){if(error!==mskConversionReason)return false}
}
return mskEmpty.currentTime===5&&!mskEmpty.seeking&&mskEmptyRuns===0;
})()')! == 'true'
	assert media_seek_raw_owner_take_task(document) == none
	empty_media := html.html_media_element_for_dom_element(empty) or { panic('Source-empty native seek owner missing') }
	assert empty_media.event_count('seeking') == 0 && empty_media.event_count('seeked') == 0 && empty_media.event_count('timeupdate') == 0
	media, clock := media_seek_raw_owner_prepare(mut runtime, video, 'mskVideo')!
	media_seek_raw_owner_finish_bridge(mut runtime, media, '__mediaSeekRawGatedFinish')!
	body := r'"use strict";mskRuns++;mskOrder.push("strict-seeking");mskSaved.push(event);mskChecks.push(arguments.length===1&&event===arguments[0]&&this===mskVideo&&event.target===mskVideo&&event.currentTarget===mskVideo&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event&&this.seeking&&this.currentTime===6&&__mediaSeekRawOwnerContext());try{void arguments.callee;mskChecks.push(false)}catch(error){mskChecks.push(error instanceof TypeError)}this.onseeking=null;globalThis.mskLiveName=onseeking;throw mskReason;'
	seeked_body := r'mskSeekedRuns++;mskOrder.push("raw-seeked");mskSaved.push(event);mskChecks.push(event.isTrusted&&this===mskVideo&&window.event===event&&!this.seeking&&this.currentTime===6&&__mediaSeekRawOwnerContext());return false;'
	assert runtime.evaluate_host('mskVideo.setAttribute("onseeking",${json2.encode(body)});mskVideo.setAttribute("onseeked",${json2.encode(seeked_body)});mskVideo.paused')! == 'true'
	seeking_slot := native_video.data.event_handler('seeking') or { panic('Strict seeking slot missing') }
	seeked_slot := native_video.data.event_handler('seeked') or { panic('Raw seeked slot missing') }
	mut owner := app.page_model
	owner.set_is_scripting_enabled(false)
	assert runtime.evaluate_host('mskVideo.currentTime=6;mskVideo.seeking&&mskVideo.onseeking===null&&mskVideo.onseeked===null&&mskRuns===0&&mskSeekedRuns===0')! == 'true'
	media_seek_raw_owner_drain(document)
	assert runtime.evaluate_host('__mediaSeekRawGatedFinish()&&!mskVideo.seeking&&mskRuns===0&&mskSeekedRuns===0')! == 'true'
	media_seek_raw_owner_drain(document)
	assert seeking_slot.value.kind == .string && seeking_slot.value.string_data == body
	assert seeked_slot.value.kind == .string && seeked_slot.value.string_data == seeked_body
	assert runtime.evaluate_host('mskRuns===0&&mskSeekedRuns===0&&mskSaved.length===0&&mskOrder.length===0&&mskEmptyRuns===0')! == 'true'
	media_seek_raw_owner_balance(runtime, document, 0)
	owner.set_is_scripting_enabled(true)
	assert runtime.evaluate_host(r'
globalThis.mskStrict=mskVideo.onseeking;globalThis.mskSeeked=mskVideo.onseeked;
mskVideo.addEventListener("seeking",function(event){mskOrder.push("later-seeking");globalThis.mskLater=this===mskVideo&&event.currentTarget===mskVideo&&event.isTrusted&&!event.defaultPrevented&&window.event===event&&this.seeking&&this.currentTime===6;document.getElementById("msk-result").textContent="later native seeking listener"});typeof mskStrict==="function"&&mskStrict.name==="onseeking"&&mskStrict.length===1&&mskVideo.onseeking===mskStrict&&typeof mskSeeked==="function"&&mskSeeked.name==="onseeked"&&mskVideo.onseeked===mskSeeked&&mskRuns===0
')! == 'true'
	strict_callback := native_video.get_current_value_of_event_handler('seeking') or { panic('Strict seeking callback missing') }
	assert strict_callback.compiled_source_text_ == 'function onseeking(event) {\n${body}\n}'
	assert runtime.javascript_event_handler(native_video, 'seeking')! == runtime.evaluate_host_value('mskStrict')!
	assert runtime.evaluate_host('mskVideo.fastSeek(6);mskVideo.seeking&&mskOrder.length===0')! == 'true'
	media_seek_raw_owner_drain(document)
	assert runtime.evaluate_host('mskOrder.join(",")==="strict-seeking,later-seeking"&&mskRuns===1&&mskSeekedRuns===0&&mskLiveName===null&&mskVideo.onseeking===null&&mskLater&&mskChecks.length===2&&mskChecks.every(Boolean)&&window.event===undefined')! == 'true'
	assert !native_video.data.has_event_handler('seeking') && native_video.data.has_event_handler('seeked')
	assert video.get_attribute_value('onseeking') == body && video.get_attribute_value('onseeked') == seeked_body
	assert settings.realm().reported_exceptions.len == 1
	reported := settings.realm().reported_exceptions[0].value.as_webidl_value()!
	assert runtime.actual_webidl_value(reported)! == runtime.evaluate_host_value('mskReason')!
	assert runtime.evaluate_host('__mediaSeekRawGatedFinish()&&!mskVideo.seeking&&mskSeekedRuns===0')! == 'true'
	media_seek_raw_owner_drain(document)
	assert runtime.evaluate_host('mskRuns===1&&mskSeekedRuns===1&&mskChecks.length===3&&mskChecks.every(Boolean)&&mskVideo.onseeked===mskSeeked&&mskSaved.length===2&&!mskSaved[0].defaultPrevented&&mskSaved[1].defaultPrevented&&mskOrder.join(",")==="strict-seeking,later-seeking,raw-seeked"&&mskEmptyRuns===0&&window.event===undefined')! == 'true'
	assert media.event_count('seeking') == 2 && media.event_count('seeked') == 2 && media.event_count('timeupdate') == 2
	assert clock.targets == [6.0, 6.0] && clock.modes == [.accurate, .accurate]
	assert empty_media.ready_state() == .have_nothing && empty_media.current_time() == 5
	assert empty_media.event_count('seeking') == 0 && empty_media.event_count('seeked') == 0 && empty_media.event_count('timeupdate') == 0
	for index in 0 .. 2 {
		event := runtime.native_event(runtime.evaluate_host_value('mskSaved[${index}]')!)!
		media_seek_raw_owner_event(mut runtime, event, 'mskSaved[${index}]')!
	}
	app.poll_javascript_tasks()
	assert document.get_element_by_id('msk-result')?.text_content()? == 'later native seeking listener'
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'later native seeking listener').len > 0
	assert app.js_messages == []
	media_seek_raw_owner_balance(runtime, document, 1)
}

