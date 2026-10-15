module main

import browserjs
import dom
import html
import json2
import page
import time

const media_loadstart_raw_owner_markup = '<!doctype html><style>
html,body{margin:0}#mls-video{display:block;width:180px;height:60px}
#mls-result{position:absolute;top:100px;left:0}
</style><form id="mls-form"><video id="mls-video"></video></form><div id="mls-result">waiting</div>'

@[heap]
struct MediaLoadstartRawOwnerObservation {
mut:
	events []&dom.Event
	targets []voidptr
}

@[heap]
struct MediaLoadstartRawOwnerFetch {
mut:
	urls []string
	offsets []u64
	loadstarts []int
}

fn media_loadstart_raw_owner_fixture(markup string, source string) !(&BrowserApp, &dom.Document, &browserjs.Runtime) {
	mut owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{
		value: 'https://media-loadstart-raw-owner.example.test/'
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

fn media_loadstart_raw_owner_take_task(document &dom.Document) ?&html.Task {
	mut queue := html.main_thread_event_loop().task_queue()
	return queue.take_first_runnable_matching(fn [document] (task &html.Task) bool {
		owner := task.document() or { return false }
		return task.source() == .media_element && voidptr(owner) == voidptr(document)
	})
}

fn media_loadstart_raw_owner_drain(document &dom.Document) {
	mut count := 0
	for {
		task := media_loadstart_raw_owner_take_task(document) or { break }
		count++
		assert count < 100
		task.execute()
	}
}

fn media_loadstart_raw_owner_probe(mut runtime browserjs.Runtime, document &dom.Document) ! {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	handle := voidptr(&runtime)
	actual_true := runtime.evaluate_host_value('true')!
	runtime.define_value_host_function('__mediaLoadstartRawOwnerContext', fn [settings, handle, actual_true] (_ voidptr, args []voidptr) !voidptr {
		owner := unsafe { &browserjs.Runtime(handle) }
		assert args.len == 0
		assert settings.realm().script_execution_depth > 0 && settings.realm().callback_execution_depth > 0
		assert owner.libjs_vm().has_running_execution_context()
		assert voidptr(html.current_principal_settings_object()) == voidptr(settings)
		assert voidptr(html.incumbent_settings_object()) == voidptr(settings)
		return actual_true
	})!
}

fn media_loadstart_raw_owner_observe(element &dom.Element, observation &MediaLoadstartRawOwnerObservation) {
	handle := voidptr(observation)
	callback := &dom.CallbackType{
		handle_event: fn [handle] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut saved := unsafe { &MediaLoadstartRawOwnerObservation(handle) }
			assert event.type_name() in ['loadstart']
			assert event.interface_ == .event && event.is_trusted()
			// The handler algorithm applies exact false to the canceled flag,
			// including native loadstart events whose cancelable flag is false.
			assert !event.bubbles() && !event.cancelable() && event.default_prevented()
			saved.events << event
			saved.targets << voidptr(event.target() or { panic('Native loadstart event needs its owner') })
			return dom.js_undefined()
		}
	}
	for name in ['loadstart'] {
		unsafe { &dom.EventTarget(element) }.add_event_listener_without_options(name, dom.IDLEventListener.create(callback))
	}
}

fn media_loadstart_raw_owner_event(mut runtime browserjs.Runtime, event &dom.Event, expression string) ! {
	wrapper := runtime.evaluate_host_value(expression)!
	assert voidptr(runtime.native_event(wrapper)!) == voidptr(event)
	assert runtime.javascript_event(event)! == wrapper
	assert event.is_trusted() && event.current_target() == none && event.event_phase() == 0
	assert runtime.evaluate_host('${expression}.currentTarget===null&&${expression}.eventPhase===Event.NONE&&window.event===undefined')! == 'true'
}

fn media_loadstart_raw_owner_balance(runtime &browserjs.Runtime, document &dom.Document, exceptions int) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == exceptions
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn media_loadstart_raw_owner_configure(mut runtime browserjs.Runtime, element &dom.Element, pending_name string) !(&html.HTMLMediaElement, &MediaLoadstartRawOwnerFetch) {
	mut media := html.html_media_element_for_dom_element(element) or { return error('Missing loadstart media owner') }
	media_handle := voidptr(media)
	state := &MediaLoadstartRawOwnerFetch{}
	media.set_fetch_hook(fn [state, media_handle] (url dom.URL, offset u64) !html.MediaResourceResponse {
		mut observation := unsafe { &MediaLoadstartRawOwnerFetch(state) }
		owner := unsafe { &html.HTMLMediaElement(media_handle) }
		observation.urls << url.serialize()
		observation.offsets << offset
		observation.loadstarts << owner.event_count('loadstart')
		return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 20 }
	})
	actual_true := runtime.evaluate_host_value('true')!
	runtime.define_value_host_function(pending_name, fn [state, media_handle, actual_true] (_ voidptr, args []voidptr) !voidptr {
		assert args.len == 0
		owner := unsafe { &html.HTMLMediaElement(media_handle) }
		assert owner.error() == none
		// Used by sequential src/explicit-load callbacks, before their hook runs.
		assert state.urls.len + 1 == owner.event_count('loadstart')
		return actual_true
	})!
	return media, state
}

fn media_loadstart_raw_owner_queue_bridge(mut runtime browserjs.Runtime, media &html.HTMLMediaElement) ! {
	media_handle := voidptr(media)
	runtime_handle := voidptr(&runtime)
	actual_true := runtime.evaluate_host_value('true')!
	runtime.define_value_host_function('__mediaLoadstartRawQueueLoad', fn [media_handle, runtime_handle, actual_true] (_ voidptr, args []voidptr) !voidptr {
		assert args.len == 0
		owner := unsafe { &html.HTMLMediaElement(media_handle) }
		owner.queue_a_media_element_task(fn [runtime_handle] () {
			mut current_runtime := unsafe { &browserjs.Runtime(runtime_handle) }
			result := current_runtime.evaluate_host('mlsCallOpen=true;mlsVideo.load();mlsCallOpen=false;true') or { panic(err.msg()) }
			assert result == 'true'
		})
		return actual_true
	})!
}

fn test_media_raw_loadstart_parsed_created_scopes_trusted_events_before_fetch_and_native_load_return() {
	$if !darwin { return }
	body := r'mlsRuns++;mlsOrder.push(this.id+":"+event.type);mlsScopes.push(scopeKey);delete this.scopeKey;mlsScopes.push(scopeKey);delete document.scopeKey;mlsScopes.push(scopeKey);document.scopeKey="document";this.scopeKey=this.id==="mls-video"?"parsed element":"created element";mlsSaved.push(event);mlsChecks.push(arguments.length===1&&event===arguments[0]&&(this===mlsVideo||this===mlsAudio)&&event.target===this&&event.currentTarget===this&&event instanceof Event&&event.type==="loadstart"&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event&&document===mlsDocument&&getElementById("mls-result")===mlsResult&&mlsCallOpen&&networkState===2&&readyState===0&&currentSrc===""&&Number.isNaN(duration)&&currentTime===0&&paused===true&&__mediaLoadstartRawOwnerContext()&&(this===mlsVideo?__mediaLoadstartRawVideoPending():__mediaLoadstartRawAudioPending()));getElementById("mls-result").textContent="raw native loadstart painted";this.style.color="rgb(0,128,0)";return false;'
	attribute_body := body.replace('"', '&quot;')
	markup := media_loadstart_raw_owner_markup.replace('<video id="mls-video">',
		'<video id="mls-video" onloadstart="${attribute_body}">')
	mut app, mut document, mut runtime := media_loadstart_raw_owner_fixture(markup, r'
globalThis.mlsVideo=document.getElementById("mls-video");globalThis.mlsDocument=document;globalThis.mlsResult=document.getElementById("mls-result");globalThis.mlsForm=document.getElementById("mls-form");
globalThis.mlsRuns=0;globalThis.mlsOrder=[];globalThis.mlsScopes=[];globalThis.mlsSaved=[];globalThis.mlsChecks=[];globalThis.mlsCallOpen=false;globalThis.scopeKey="global";
document.scopeKey="document";mlsForm.scopeKey="nearest form";mlsVideo.scopeKey="parsed element";mlsVideo.event={sentinel:true};document.event={sentinel:true};
globalThis.mlsAudio=document.createElement("audio");mlsAudio.id="mls-audio";mlsAudio.setAttribute("onloadstart",mlsVideo.getAttribute("onloadstart"));document.body.appendChild(mlsAudio);mlsAudio.scopeKey="created element";void mlsAudio.paused;0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	media_loadstart_raw_owner_probe(mut runtime, document)!
	video := document.get_element_by_id('mls-video')?
	audio := document.get_element_by_id('mls-audio')?
	native_video := unsafe { &dom.EventTarget(video) }
	native_audio := unsafe { &dom.EventTarget(audio) }
	for target in [native_video, native_audio] {
		slot := target.data.event_handler('loadstart') or { panic('Raw loadstart slot missing') }
		assert slot.value.kind == .string && slot.value.string_data == body
	}
	assert runtime.evaluate_host('globalThis.mlsVideoStart=mlsVideo.onloadstart;globalThis.mlsAudioStart=mlsAudio.onloadstart;typeof mlsVideoStart==="function"&&typeof mlsAudioStart==="function"&&mlsVideoStart!==mlsAudioStart&&mlsVideoStart.name==="onloadstart"&&mlsAudioStart.name==="onloadstart"&&mlsVideoStart.length===1&&mlsAudioStart.length===1&&mlsVideo.onloadstart===mlsVideoStart&&mlsAudio.onloadstart===mlsAudioStart&&!Object.hasOwn(mlsVideo,"onloadstart")&&!Object.hasOwn(mlsAudio,"onloadstart")&&mlsRuns===0')! == 'true'
	for target in [native_video, native_audio] {
		callback := target.get_current_value_of_event_handler('loadstart') or { panic('Cached loadstart callback missing') }
		assert callback.compiled_source_text_ == 'function onloadstart(event) {\n${body}\n}'
		alias := if voidptr(target) == voidptr(native_video) { 'mlsVideo' } else { 'mlsAudio' }
		assert runtime.javascript_event_handler(target, 'loadstart')! == runtime.evaluate_host_value('${alias}.onloadstart')!
	}
	video_media, video_fetch := media_loadstart_raw_owner_configure(mut runtime, video, '__mediaLoadstartRawVideoPending')!
	audio_media, audio_fetch := media_loadstart_raw_owner_configure(mut runtime, audio, '__mediaLoadstartRawAudioPending')!
	observation := &MediaLoadstartRawOwnerObservation{}
	media_loadstart_raw_owner_observe(video, observation)
	media_loadstart_raw_owner_observe(audio, observation)
	assert runtime.evaluate_host('mlsVideo.load();mlsAudio.load();mlsRuns===0&&mlsOrder.length===0&&mlsVideo.networkState===0&&mlsAudio.networkState===0')! == 'true'
	assert media_loadstart_raw_owner_take_task(document) == none
	assert video_fetch.urls.len == 0 && audio_fetch.urls.len == 0
	// src replay invokes the automatic load_element() path. Flush that first,
	// then explicit load() dispatches a second synchronous loadstart per owner.
	assert runtime.evaluate_host('mlsCallOpen=true;mlsVideo.src="/video-start.mp4";void mlsVideo.paused;mlsVideo.load();mlsCallOpen=false;mlsRuns===2&&mlsVideo.readyState===1&&mlsVideo.networkState===1&&mlsVideo.currentSrc==="https://media-loadstart-raw-owner.example.test/video-start.mp4"&&mlsVideo.duration===20')! == 'true'
	assert runtime.evaluate_host('mlsCallOpen=true;mlsAudio.src="/audio-start.mp4";void mlsAudio.paused;mlsAudio.load();mlsCallOpen=false;mlsRuns===4&&mlsAudio.readyState===1&&mlsAudio.networkState===1&&mlsAudio.currentSrc==="https://media-loadstart-raw-owner.example.test/audio-start.mp4"&&mlsAudio.duration===20')! == 'true'
	assert video_fetch.urls == ['https://media-loadstart-raw-owner.example.test/video-start.mp4', 'https://media-loadstart-raw-owner.example.test/video-start.mp4']
	assert audio_fetch.urls == ['https://media-loadstart-raw-owner.example.test/audio-start.mp4', 'https://media-loadstart-raw-owner.example.test/audio-start.mp4']
	assert video_fetch.offsets == [u64(0), 0] && audio_fetch.offsets == [u64(0), 0]
	assert video_fetch.loadstarts == [1, 2] && audio_fetch.loadstarts == [1, 2]
	assert video_media.error() == none && audio_media.error() == none
	assert runtime.evaluate_host('mlsOrder.join(",")==="mls-video:loadstart,mls-video:loadstart,mls-audio:loadstart,mls-audio:loadstart"&&mlsScopes.join(",")==="parsed element,document,global,parsed element,document,global,created element,document,global,created element,document,global"&&mlsChecks.length===4&&mlsChecks.every(Boolean)&&mlsSaved.every(event=>event.defaultPrevented)&&mlsVideo.onloadstart===mlsVideoStart&&mlsAudio.onloadstart===mlsAudioStart&&mlsForm.scopeKey==="nearest form"&&window.event===undefined')! == 'true'
	assert observation.events.len == 4
	assert observation.targets == [voidptr(video), voidptr(video), voidptr(audio), voidptr(audio)]
	for index, event in observation.events {
		media_loadstart_raw_owner_event(mut runtime, event, 'mlsSaved[${index}]')!
	}
	media_loadstart_raw_owner_drain(document)
	assert video_media.event_count('loadstart') == 2 && audio_media.event_count('loadstart') == 2
	// V dispatches inside selection before currentSrc is installed. Pinned
	// upstream queues selection/loadstart and installs the URL before delivery;
	// this preserved scheduling boundary is outside the raw-handler feature.
	app.poll_javascript_tasks()
	assert document.get_element_by_id('mls-result')?.text_content()? == 'raw native loadstart painted'
	assert video.get_attribute_value('style').contains('color') && audio.get_attribute_value('style').contains('color')
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'raw native loadstart painted').len > 0
	assert app.js_messages == []
	media_loadstart_raw_owner_balance(runtime, document, 0)
}

fn test_media_raw_loadstart_equal_attributes_prequeued_latest_body_nested_load_and_removal() {
	$if !darwin { return }
	body := r'mlsRuns++;mlsOrder.push("original");mlsSaved.push(event);return false;'
	attribute_body := body.replace('"', '&quot;')
	markup := media_loadstart_raw_owner_markup.replace('<video id="mls-video">',
		'<video id="mls-video" onloadstart="${attribute_body}">')
	mut app, mut document, mut runtime := media_loadstart_raw_owner_fixture(markup, r'
globalThis.mlsVideo=document.getElementById("mls-video");globalThis.mlsRuns=0;globalThis.mlsOrder=[];globalThis.mlsSaved=[];globalThis.mlsChecks=[];globalThis.mlsCallOpen=false;globalThis.mlsSource=mlsVideo.getAttribute("onloadstart");globalThis.mlsFirst=mlsVideo.onloadstart;
globalThis.mlsIDL=function(event){mlsRuns++;mlsOrder.push("idl");mlsSaved.push(event);mlsChecks.push(this===mlsVideo&&event.isTrusted&&event.target===this&&event.currentTarget===this&&window.event===event&&mlsCallOpen&&this.networkState===2&&this.readyState===0&&this.currentSrc===""&&Number.isNaN(this.duration)&&this.currentTime===0&&this.paused&&__mediaLoadstartRawOwnerContext());return false};0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	media_loadstart_raw_owner_probe(mut runtime, document)!
	video := document.get_element_by_id('mls-video')?
	native_video := unsafe { &dom.EventTarget(video) }
	slot := native_video.data.event_handler('loadstart') or { panic('Loadstart slot missing') }
	listener := slot.listener or { panic('Loadstart listener missing') }
	first_callback := native_video.get_current_value_of_event_handler('loadstart') or { panic('First loadstart callback missing') }
	assert runtime.evaluate_host('mlsVideo.onloadstart=mlsIDL;mlsVideo.setAttribute("onloadstart",mlsSource);globalThis.mlsSecond=mlsVideo.onloadstart;typeof mlsSecond==="function"&&mlsSecond!==mlsFirst&&mlsSecond!==mlsIDL&&mlsSecond.name==="onloadstart"&&mlsSecond.length===1&&mlsVideo.onloadstart===mlsSecond&&mlsRuns===0')! == 'true'
	assert voidptr(native_video.data.event_handler('loadstart') or { panic('Replaced loadstart slot missing') }) == voidptr(slot)
	assert voidptr(slot.listener or { panic('Replaced loadstart listener missing') }) == voidptr(listener)
	second_callback := native_video.get_current_value_of_event_handler('loadstart') or { panic('Second loadstart callback missing') }
	assert voidptr(second_callback) != voidptr(first_callback) && second_callback.compiled_source_text_ == first_callback.compiled_source_text_
	mut media, fetch := media_loadstart_raw_owner_configure(mut runtime, video, '__mediaLoadstartRawNestedPending')!
	// Seed the native source without a DOM src attribute here. This isolates
	// the queued JS load from the separately covered automatic src replay path.
	media.set_source('/same-start.mp4')
	media_loadstart_raw_owner_queue_bridge(mut runtime, media)!
	ignored_body := r'mlsRuns++;mlsOrder.push("superseded");return false;'
	queued_body := r'mlsRuns++;mlsOrder.push("replacement");mlsSaved.push(event);mlsChecks.push(event.isTrusted&&this===mlsVideo&&event.target===this&&event.currentTarget===this&&window.event===event&&mlsCallOpen&&this.networkState===2&&this.readyState===0&&this.currentSrc===""&&Number.isNaN(this.duration)&&this.currentTime===0&&this.paused&&__mediaLoadstartRawOwnerContext());this.onloadstart=mlsIDL;this.load();mlsChecks.push(mlsRuns===2&&mlsSaved.length===2&&mlsSaved[0]===event&&mlsSaved[1]!==event&&window.event===event&&event.currentTarget===this&&this.readyState===1&&this.currentSrc==="https://media-loadstart-raw-owner.example.test/same-start.mp4");document.getElementById("mls-result").textContent="nested native loadstart painted";return false;'
	assert runtime.evaluate_host('__mediaLoadstartRawQueueLoad();mlsVideo.setAttribute("onloadstart",${json2.encode(ignored_body)});mlsVideo.setAttribute("onloadstart",${json2.encode(queued_body)});mlsVideo.paused&&mlsRuns===0&&mlsOrder.length===0')! == 'true'
	assert slot.value.kind == .string && slot.value.string_data == queued_body
	(media_loadstart_raw_owner_take_task(document) or { panic('Missing queued JS load task') }).execute()
	assert runtime.evaluate_host('mlsRuns===2&&mlsOrder.join(",")==="replacement,idl"&&mlsSaved.length===2&&mlsSaved.every(event=>event.isTrusted&&event.defaultPrevented)&&mlsChecks.length===3&&mlsChecks.every(Boolean)&&mlsVideo.onloadstart===mlsIDL&&window.event===undefined')! == 'true'
	// Identical-source reentry completes its inner hook, then the existing V
	// outer selection resumes. This does not assert generation cancellation.
	assert fetch.urls == ['https://media-loadstart-raw-owner.example.test/same-start.mp4', 'https://media-loadstart-raw-owner.example.test/same-start.mp4']
	assert fetch.loadstarts == [2, 2]
	assert media.error() == none && media.event_count('loadstart') == 2
	assert voidptr(slot.listener or { panic('Nested loadstart listener missing') }) == voidptr(listener)
	media_loadstart_raw_owner_drain(document)
	assert runtime.evaluate_host('__mediaLoadstartRawQueueLoad();mlsVideo.removeAttribute("onloadstart");mlsVideo.onloadstart===null&&mlsRuns===2')! == 'true'
	assert !native_video.data.has_event_handler('loadstart') && video.get_attribute('onloadstart') == none
	media_loadstart_raw_owner_drain(document)
	assert runtime.evaluate_host('mlsRuns===2&&mlsOrder.length===2&&mlsSaved.length===2')! == 'true'
	assert runtime.evaluate_host('mlsVideo.onloadstart=mlsIDL;mlsVideo.removeAttribute("onloadstart");__mediaLoadstartRawQueueLoad();mlsVideo.onloadstart===mlsIDL&&mlsRuns===2')! == 'true'
	media_loadstart_raw_owner_drain(document)
	assert runtime.evaluate_host('mlsRuns===3&&mlsOrder.join(",")==="replacement,idl,idl"&&mlsChecks.length===4&&mlsChecks.every(Boolean)&&mlsSaved.length===3&&mlsSaved.every(event=>event.isTrusted&&event.defaultPrevented)&&mlsVideo.onloadstart===mlsIDL&&window.event===undefined')! == 'true'
	assert native_video.event_listener_list().len == 1
	assert fetch.urls.len == 4 && fetch.loadstarts == [2, 2, 3, 4] && media.event_count('loadstart') == 4
	for index in 0 .. 3 {
		event := runtime.native_event(runtime.evaluate_host_value('mlsSaved[${index}]')!)!
		media_loadstart_raw_owner_event(mut runtime, event, 'mlsSaved[${index}]')!
	}
	app.poll_javascript_tasks()
	assert document.get_element_by_id('mls-result')?.text_content()? == 'nested native loadstart painted'
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'nested native loadstart painted').len > 0
	assert app.js_messages == []
	media_loadstart_raw_owner_balance(runtime, document, 0)
}

fn test_media_raw_loadstart_scripting_gate_strict_original_exception_later_listener_and_response() {
	$if !darwin { return }
	mut app, mut document, mut runtime := media_loadstart_raw_owner_fixture(media_loadstart_raw_owner_markup, r'
globalThis.mlsVideo=document.getElementById("mls-video");globalThis.mlsRuns=0;globalThis.mlsChecks=[];globalThis.mlsSaved=[];globalThis.mlsReason={original:true};globalThis.mlsOrder=[];globalThis.mlsCallOpen=false;mlsVideo.event={sentinel:true};document.event={sentinel:true};0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	media_loadstart_raw_owner_probe(mut runtime, document)!
	video := document.get_element_by_id('mls-video')?
	native_video := unsafe { &dom.EventTarget(video) }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	media, fetch := media_loadstart_raw_owner_configure(mut runtime, video, '__mediaLoadstartRawStrictPending')!
	body := r'"use strict";mlsRuns++;mlsOrder.push("strict-loadstart");mlsSaved.push(event);mlsChecks.push(arguments.length===1&&event===arguments[0]&&this===mlsVideo&&event.target===mlsVideo&&event.currentTarget===mlsVideo&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event&&mlsCallOpen&&this.networkState===2&&this.readyState===0&&this.currentSrc===""&&Number.isNaN(this.duration)&&this.currentTime===0&&this.paused&&__mediaLoadstartRawOwnerContext()&&__mediaLoadstartRawStrictPending());try{void arguments.callee;mlsChecks.push(false)}catch(error){mlsChecks.push(error instanceof TypeError)}this.onloadstart=null;globalThis.mlsLiveName=onloadstart;throw mlsReason;'
	assert runtime.evaluate_host('mlsVideo.setAttribute("onloadstart",${json2.encode(body)});mlsVideo.paused')! == 'true'
	slot := native_video.data.event_handler('loadstart') or { panic('Strict loadstart slot missing') }
	mut owner := app.page_model
	owner.set_is_scripting_enabled(false)
	assert runtime.evaluate_host('mlsVideo.src="/gated-start.mp4";void mlsVideo.paused;mlsVideo.load();mlsVideo.onloadstart===null&&mlsRuns===0&&mlsVideo.readyState===1&&mlsVideo.networkState===1')! == 'true'
	assert slot.value.kind == .string && slot.value.string_data == body
	assert fetch.urls.len == 2 && fetch.loadstarts == [1, 2] && media.event_count('loadstart') == 2
	media_loadstart_raw_owner_drain(document)
	assert runtime.evaluate_host('mlsRuns===0&&mlsSaved.length===0&&mlsOrder.length===0')! == 'true'
	media_loadstart_raw_owner_balance(runtime, document, 0)
	owner.set_is_scripting_enabled(true)
	assert runtime.evaluate_host(r'
globalThis.mlsStrict=mlsVideo.onloadstart;
mlsVideo.addEventListener("loadstart",function(event){mlsOrder.push("later-loadstart");globalThis.mlsLater=this===mlsVideo&&event.currentTarget===mlsVideo&&event.isTrusted&&!event.defaultPrevented&&window.event===event&&this.networkState===2&&this.readyState===0&&this.currentSrc==="";document.getElementById("mls-result").textContent="later native loadstart listener"});typeof mlsStrict==="function"&&mlsStrict.name==="onloadstart"&&mlsStrict.length===1&&mlsVideo.onloadstart===mlsStrict&&mlsRuns===0
')! == 'true'
	strict_callback := native_video.get_current_value_of_event_handler('loadstart') or { panic('Strict loadstart callback missing') }
	assert strict_callback.compiled_source_text_ == 'function onloadstart(event) {\n${body}\n}'
	assert runtime.javascript_event_handler(native_video, 'loadstart')! == runtime.evaluate_host_value('mlsStrict')!
	assert runtime.evaluate_host('mlsCallOpen=true;mlsVideo.load();mlsCallOpen=false;mlsRuns===1&&mlsOrder.join(",")==="strict-loadstart,later-loadstart"&&mlsLiveName===null&&mlsVideo.onloadstart===null&&mlsLater&&mlsChecks.length===2&&mlsChecks.every(Boolean)&&mlsSaved.length===1&&!mlsSaved[0].defaultPrevented&&mlsVideo.readyState===1&&mlsVideo.networkState===1&&mlsVideo.currentSrc==="https://media-loadstart-raw-owner.example.test/gated-start.mp4"&&mlsVideo.duration===20&&window.event===undefined')! == 'true'
	assert !native_video.data.has_event_handler('loadstart') && video.get_attribute_value('onloadstart') == body
	assert settings.realm().reported_exceptions.len == 1
	reported := settings.realm().reported_exceptions[0].value.as_webidl_value()!
	assert runtime.actual_webidl_value(reported)! == runtime.evaluate_host_value('mlsReason')!
	assert fetch.urls.len == 3 && fetch.loadstarts == [1, 2, 3] && media.error() == none
	media_loadstart_raw_owner_drain(document)
	event := runtime.native_event(runtime.evaluate_host_value('mlsSaved[0]')!)!
	media_loadstart_raw_owner_event(mut runtime, event, 'mlsSaved[0]')!
	app.poll_javascript_tasks()
	assert document.get_element_by_id('mls-result')?.text_content()? == 'later native loadstart listener'
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'later native loadstart listener').len > 0
	assert app.js_messages == []
	media_loadstart_raw_owner_balance(runtime, document, 1)
}

