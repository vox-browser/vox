module main

import browserjs
import dom
import html
import json2
import page
import time

const media_data_raw_owner_markup = '<!doctype html><style>
html,body{margin:0}#mdr-video{display:block;width:180px;height:60px}
#mdr-result{position:absolute;top:100px;left:0}
</style><form id="mdr-form"><video id="mdr-video"></video></form><div id="mdr-result">waiting</div>'

@[heap]
struct MediaDataRawOwnerObservation {
mut:
	events []&dom.Event
	targets []voidptr
}

fn media_data_raw_owner_fixture(markup string, source string) !(&BrowserApp, &dom.Document, &browserjs.Runtime) {
	mut owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{
		value: 'https://media-data-raw-owner.example.test/'
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

fn media_data_raw_owner_take_task(document &dom.Document) ?&html.Task {
	mut queue := html.main_thread_event_loop().task_queue()
	return queue.take_first_runnable_matching(fn [document] (task &html.Task) bool {
		owner := task.document() or { return false }
		return task.source() == .media_element && voidptr(owner) == voidptr(document)
	})
}

fn media_data_raw_owner_drain(document &dom.Document) {
	mut count := 0
	for {
		task := media_data_raw_owner_take_task(document) or { break }
		count++
		assert count < 100
		task.execute()
	}
}

fn media_data_raw_owner_checkpoint() {
	mut loop := html.main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
}

fn media_data_raw_owner_prepare(mut runtime browserjs.Runtime, element &dom.Element, alias string) !&html.HTMLMediaElement {
	mut media := media_data_raw_owner_configure(element)!
	assert runtime.evaluate_host('${alias}.src="/data.mp4";${alias}.load();${alias}.readyState===1')! == 'true'
	media.set_show_poster(false)
	assert media.paused() && media.ready_state() == .have_metadata
	return media
}

fn media_data_raw_owner_configure(element &dom.Element) !&html.HTMLMediaElement {
	mut media := html.html_media_element_for_dom_element(element) or { return error('Missing data media owner') }
	media.set_fetch_hook(fn (_ dom.URL, _ u64) !html.MediaResourceResponse {
		return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 20 }
	})
	return media
}

fn media_data_raw_owner_probe(mut runtime browserjs.Runtime, document &dom.Document) ! {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	handle := voidptr(&runtime)
	actual_true := runtime.evaluate_host_value('true')!
	runtime.define_value_host_function('__mediaDataRawOwnerContext', fn [settings, handle, actual_true] (_ voidptr, args []voidptr) !voidptr {
		owner := unsafe { &browserjs.Runtime(handle) }
		assert args.len == 0
		assert settings.realm().script_execution_depth > 0 && settings.realm().callback_execution_depth > 0
		assert owner.libjs_vm().has_running_execution_context()
		assert voidptr(html.current_principal_settings_object()) == voidptr(settings)
		assert voidptr(html.incumbent_settings_object()) == voidptr(settings)
		return actual_true
	})!
}

fn media_data_raw_owner_observe(element &dom.Element, observation &MediaDataRawOwnerObservation) {
	handle := voidptr(observation)
	callback := &dom.CallbackType{
		handle_event: fn [handle] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut saved := unsafe { &MediaDataRawOwnerObservation(handle) }
			assert event.type_name() in ['loadedmetadata', 'loadeddata']
			assert event.interface_ == .event && event.is_trusted()
			// The handler algorithm applies exact false to the canceled flag,
			// including native data events whose cancelable flag is false.
			assert !event.bubbles() && !event.cancelable() && event.default_prevented()
			saved.events << event
			saved.targets << voidptr(event.target() or { panic('Native data event needs its owner') })
			return dom.js_undefined()
		}
	}
	for name in ['loadedmetadata', 'loadeddata'] {
		unsafe { &dom.EventTarget(element) }.add_event_listener_without_options(name, dom.IDLEventListener.create(callback))
	}
}

fn media_data_raw_owner_event(mut runtime browserjs.Runtime, event &dom.Event, expression string) ! {
	wrapper := runtime.evaluate_host_value(expression)!
	assert voidptr(runtime.native_event(wrapper)!) == voidptr(event)
	assert runtime.javascript_event(event)! == wrapper
	assert event.is_trusted() && event.current_target() == none && event.event_phase() == 0
	assert runtime.evaluate_host('${expression}.currentTarget===null&&${expression}.eventPhase===Event.NONE&&window.event===undefined')! == 'true'
}

fn media_data_raw_owner_balance(runtime &browserjs.Runtime, document &dom.Document, exceptions int) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == exceptions
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_media_raw_loadedmetadata_loadeddata_parsed_created_scopes_trusted_events_and_play_order() {
	$if !darwin { return }
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	body := r'mdrRuns++;mdrOrder.push(this.id+":"+event.type);mdrScopes.push(scopeKey);delete this.scopeKey;mdrScopes.push(scopeKey);delete document.scopeKey;mdrScopes.push(scopeKey);document.scopeKey="document";this.scopeKey=this.id==="mdr-video"?"parsed element":"created element";mdrSaved.push(event);mdrChecks.push(arguments.length===1&&event===arguments[0]&&(this===mdrVideo||this===mdrAudio)&&event.target===this&&event.currentTarget===this&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event&&document===mdrDocument&&getElementById("mdr-result")===mdrResult&&this.readyState===(event.type==="loadedmetadata"?1:4)&&mdrValues.length===(this===mdrAudio&&event.type==="loadeddata"?1:0)&&__mediaDataRawOwnerContext());getElementById("mdr-result").textContent="raw media data painted";this.style.color="rgb(0,128,0)";return false;'
	attribute_body := body.replace('"', '&quot;')
	markup := media_data_raw_owner_markup.replace('<video id="mdr-video">',
		'<video id="mdr-video" onloadedmetadata="${attribute_body}" onloadeddata="${attribute_body}">')
	mut app, mut document, mut runtime := media_data_raw_owner_fixture(markup, r'
globalThis.mdrVideo=document.getElementById("mdr-video");globalThis.mdrDocument=document;globalThis.mdrResult=document.getElementById("mdr-result");globalThis.mdrForm=document.getElementById("mdr-form");
globalThis.mdrRuns=0;globalThis.mdrOrder=[];globalThis.mdrScopes=[];globalThis.mdrSaved=[];globalThis.mdrChecks=[];globalThis.mdrReasons=[];globalThis.mdrValues=[];globalThis.scopeKey="global";
document.scopeKey="document";mdrForm.scopeKey="nearest form";mdrVideo.scopeKey="parsed element";mdrVideo.event={sentinel:true};document.event={sentinel:true};
globalThis.mdrAudio=document.createElement("audio");mdrAudio.id="mdr-audio";mdrAudio.setAttribute("onloadedmetadata",mdrVideo.getAttribute("onloadedmetadata"));mdrAudio.setAttribute("onloadeddata",mdrVideo.getAttribute("onloadeddata"));document.body.appendChild(mdrAudio);mdrAudio.scopeKey="created element";void mdrAudio.paused;
for(var mdrElement of [mdrVideo,mdrAudio])for(var mdrEventName of ["canplay","playing"])mdrElement.addEventListener(mdrEventName,function(event){mdrOrder.push(this.id+":"+event.type);mdrChecks.push(this===event.target&&event.isTrusted&&!event.defaultPrevented&&mdrValues.length===(this===mdrAudio?1:0))});0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	media_data_raw_owner_probe(mut runtime, document)!
	video := document.get_element_by_id('mdr-video')?
	audio := document.get_element_by_id('mdr-audio')?
	native_video := unsafe { &dom.EventTarget(video) }
	native_audio := unsafe { &dom.EventTarget(audio) }
	for target in [native_video, native_audio] {
		for name in ['loadedmetadata', 'loadeddata'] {
			slot := target.data.event_handler(name) or { panic('Raw data slot missing') }
			assert slot.value.kind == .string && slot.value.string_data == body
		}
	}
	assert runtime.evaluate_host(r'
globalThis.mdrVideoMetadata=mdrVideo.onloadedmetadata;globalThis.mdrVideoData=mdrVideo.onloadeddata;globalThis.mdrAudioMetadata=mdrAudio.onloadedmetadata;globalThis.mdrAudioData=mdrAudio.onloadeddata;
[mdrVideoMetadata,mdrVideoData,mdrAudioMetadata,mdrAudioData].every(value=>typeof value==="function"&&value.length===1)&&mdrVideoMetadata.name==="onloadedmetadata"&&mdrAudioMetadata.name==="onloadedmetadata"&&mdrVideoData.name==="onloadeddata"&&mdrAudioData.name==="onloadeddata"&&new Set([mdrVideoMetadata,mdrVideoData,mdrAudioMetadata,mdrAudioData]).size===4&&mdrVideo.onloadedmetadata===mdrVideoMetadata&&mdrVideo.onloadeddata===mdrVideoData&&mdrAudio.onloadedmetadata===mdrAudioMetadata&&mdrAudio.onloadeddata===mdrAudioData&&!Object.hasOwn(mdrVideo,"onloadedmetadata")&&!Object.hasOwn(mdrAudio,"onloadeddata")&&mdrRuns===0
')! == 'true'
	for target in [native_video, native_audio] {
		for name in ['loadedmetadata', 'loadeddata'] {
			callback := target.get_current_value_of_event_handler(name) or { panic('Cached data callback missing') }
			assert callback.compiled_source_text_ == 'function on${name}(event) {\n${body}\n}'
			alias := if voidptr(target) == voidptr(native_video) { 'mdrVideo' } else { 'mdrAudio' }
			assert runtime.javascript_event_handler(target, name)! == runtime.evaluate_host_value('${alias}.on${name}')!
		}
	}
	observation := &MediaDataRawOwnerObservation{}
	media_data_raw_owner_observe(video, observation)
	media_data_raw_owner_observe(audio, observation)
	// Metadata is queued by the actual fetch adapter and remains undelivered
	// until the native queue runs; both observers are installed before loading.
	mut video_media := media_data_raw_owner_prepare(mut runtime, video, 'mdrVideo')!
	mut audio_media := media_data_raw_owner_prepare(mut runtime, audio, 'mdrAudio')!
	assert runtime.evaluate_host(r'
globalThis.mdrVideoRequest=mdrVideo.play();globalThis.mdrAudioRequest=mdrAudio.play();
mdrVideoRequest.then(value=>{mdrChecks.push(value===undefined);mdrValues.push("video");mdrOrder.push("mdr-video:fulfilled")},reason=>mdrReasons.push(reason));mdrAudioRequest.then(value=>{mdrChecks.push(value===undefined);mdrValues.push("audio");mdrOrder.push("mdr-audio:fulfilled")},reason=>mdrReasons.push(reason));
mdrVideoRequest instanceof Promise&&mdrAudioRequest instanceof Promise&&mdrVideoRequest!==mdrAudioRequest&&!mdrVideo.paused&&!mdrAudio.paused&&mdrRuns===0&&mdrSaved.length===0
')! == 'true'
	video_request := video_media.play()
	audio_request := audio_media.play()
	media_data_raw_owner_drain(document)
	media_data_raw_owner_checkpoint()
	assert video_request.state() == .pending && audio_request.state() == .pending
	assert runtime.evaluate_host('mdrRuns===2&&mdrOrder.join(",")==="mdr-video:loadedmetadata,mdr-audio:loadedmetadata"&&mdrValues.length===0&&mdrChecks.every(Boolean)')! == 'true'
	// The first data crossing queues loadeddata before canplay and playing.
	// The playing callback runs before its captured play promises are resolved.
	video_media.set_ready_state(.have_enough_data)
	for index in 0 .. 4 {
		assert audio_request.state() == .pending
		if index < 3 { assert video_request.state() == .pending }
		(media_data_raw_owner_take_task(document) or { panic('Missing video readiness task') }).execute()
		media_data_raw_owner_checkpoint()
		if index == 0 {
			assert video_request.state() == .pending
			assert runtime.evaluate_host('mdrRuns===3&&mdrOrder.join(",")==="mdr-video:loadedmetadata,mdr-audio:loadedmetadata,mdr-video:loadeddata"&&mdrValues.length===0')! == 'true'
		} else if index == 1 {
			assert video_request.state() == .pending
			assert runtime.evaluate_host('mdrOrder[3]==="mdr-video:canplay"&&mdrValues.length===0')! == 'true'
		} else if index == 2 {
			assert video_request.state() == .fulfilled
			assert runtime.evaluate_host('mdrOrder.slice(-2).join(",")==="mdr-video:playing,mdr-video:fulfilled"&&mdrValues.join(",")==="video"')! == 'true'
		}
	}
	audio_media.set_ready_state(.have_enough_data)
	for index in 0 .. 4 {
		if index < 3 { assert audio_request.state() == .pending }
		(media_data_raw_owner_take_task(document) or { panic('Missing audio readiness task') }).execute()
		media_data_raw_owner_checkpoint()
		if index < 2 { assert audio_request.state() == .pending }
	}
	assert video_request.state() == .fulfilled && audio_request.state() == .fulfilled
	assert runtime.evaluate_host(r'mdrRuns===4&&mdrOrder.join(",")==="mdr-video:loadedmetadata,mdr-audio:loadedmetadata,mdr-video:loadeddata,mdr-video:canplay,mdr-video:playing,mdr-video:fulfilled,mdr-audio:loadeddata,mdr-audio:canplay,mdr-audio:playing,mdr-audio:fulfilled"&&mdrScopes.join(",")==="parsed element,document,global,created element,document,global,parsed element,document,global,created element,document,global"&&mdrChecks.length===10&&mdrChecks.every(Boolean)&&mdrSaved.every(event=>event.defaultPrevented)&&mdrValues.join(",")==="video,audio"&&mdrReasons.length===0&&mdrForm.scopeKey==="nearest form"&&mdrVideo.onloadedmetadata===mdrVideoMetadata&&mdrVideo.onloadeddata===mdrVideoData&&mdrAudio.onloadedmetadata===mdrAudioMetadata&&mdrAudio.onloadeddata===mdrAudioData&&window.event===undefined')! == 'true'
	assert observation.events.len == 4
	assert observation.targets == [voidptr(video), voidptr(audio), voidptr(video), voidptr(audio)]
	for index, event in observation.events {
		media_data_raw_owner_event(mut runtime, event, 'mdrSaved[${index}]')!
	}
	assert video_media.event_count('loadedmetadata') == 1 && video_media.event_count('loadeddata') == 1
	assert audio_media.event_count('loadedmetadata') == 1 && audio_media.event_count('loadeddata') == 1
	app.poll_javascript_tasks()
	assert document.get_element_by_id('mdr-result')?.text_content()? == 'raw media data painted'
	assert video.get_attribute_value('style').contains('color') && audio.get_attribute_value('style').contains('color')
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'raw media data painted').len > 0
	assert app.js_messages == []
	media_data_raw_owner_balance(runtime, document, 0)
}

fn test_media_raw_data_live_equal_attributes_prequeued_reentrant_replacement_and_load_reset() {
	$if !darwin { return }
	body := r'mdrOrder.push("original-"+event.type);mdrSaved.push(event);return false;'
	attribute_body := body.replace('"', '&quot;')
	markup := media_data_raw_owner_markup.replace('<video id="mdr-video">',
		'<video id="mdr-video" onloadedmetadata="${attribute_body}" onloadeddata="${attribute_body}">')
	mut app, mut document, mut runtime := media_data_raw_owner_fixture(markup, r'
globalThis.mdrVideo=document.getElementById("mdr-video");globalThis.mdrOrder=[];globalThis.mdrSaved=[];globalThis.mdrChecks=[];globalThis.mdrSource=mdrVideo.getAttribute("onloadedmetadata");globalThis.mdrFirstMetadata=mdrVideo.onloadedmetadata;globalThis.mdrFirstData=mdrVideo.onloadeddata;
globalThis.mdrMetadataIDL=function(event){mdrOrder.push("idl-metadata");mdrSaved.push(event);mdrChecks.push(this===mdrVideo&&event.isTrusted&&window.event===event&&this.readyState===1);return false};
globalThis.mdrDataIDL=function(event){mdrOrder.push("idl-data");mdrSaved.push(event);mdrChecks.push(this===mdrVideo&&event.isTrusted&&window.event===event&&this.readyState===2);return false};0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	video := document.get_element_by_id('mdr-video')?
	native_video := unsafe { &dom.EventTarget(video) }
	metadata_slot := native_video.data.event_handler('loadedmetadata') or { panic('Metadata slot missing') }
	data_slot := native_video.data.event_handler('loadeddata') or { panic('Data slot missing') }
	metadata_listener := metadata_slot.listener or { panic('Metadata listener missing') }
	data_listener := data_slot.listener or { panic('Data listener missing') }
	first_metadata := native_video.get_current_value_of_event_handler('loadedmetadata') or { panic('First metadata callback missing') }
	first_data := native_video.get_current_value_of_event_handler('loadeddata') or { panic('First data callback missing') }
	assert runtime.evaluate_host(r'
mdrVideo.onloadedmetadata=mdrMetadataIDL;mdrVideo.setAttribute("onloadedmetadata",mdrSource);globalThis.mdrSecondMetadata=mdrVideo.onloadedmetadata;
mdrVideo.onloadeddata=mdrDataIDL;mdrVideo.setAttribute("onloadeddata",mdrSource);globalThis.mdrSecondData=mdrVideo.onloadeddata;
typeof mdrSecondMetadata==="function"&&mdrSecondMetadata!==mdrFirstMetadata&&mdrSecondMetadata!==mdrMetadataIDL&&mdrSecondMetadata.name==="onloadedmetadata"&&mdrSecondMetadata.length===1&&typeof mdrSecondData==="function"&&mdrSecondData!==mdrFirstData&&mdrSecondData!==mdrDataIDL&&mdrSecondData.name==="onloadeddata"&&mdrSecondData.length===1&&mdrVideo.onloadedmetadata===mdrSecondMetadata&&mdrVideo.onloadeddata===mdrSecondData&&mdrOrder.length===0
')! == 'true'
	assert voidptr(native_video.data.event_handler('loadedmetadata') or { panic('Replaced metadata slot missing') }) == voidptr(metadata_slot)
	assert voidptr(native_video.data.event_handler('loadeddata') or { panic('Replaced data slot missing') }) == voidptr(data_slot)
	assert voidptr(metadata_slot.listener or { panic('Replaced metadata listener missing') }) == voidptr(metadata_listener)
	assert voidptr(data_slot.listener or { panic('Replaced data listener missing') }) == voidptr(data_listener)
	second_metadata := native_video.get_current_value_of_event_handler('loadedmetadata') or { panic('Second metadata callback missing') }
	second_data := native_video.get_current_value_of_event_handler('loadeddata') or { panic('Second data callback missing') }
	assert voidptr(second_metadata) != voidptr(first_metadata) && second_metadata.compiled_source_text_ == first_metadata.compiled_source_text_
	assert voidptr(second_data) != voidptr(first_data) && second_data.compiled_source_text_ == first_data.compiled_source_text_
	mut media := media_data_raw_owner_prepare(mut runtime, video, 'mdrVideo')!
	media_handle := voidptr(media)
	actual_true := runtime.evaluate_host_value('true')!
	runtime.define_value_host_function('__mediaDataRawAdvance', fn [media_handle, actual_true] (_ voidptr, args []voidptr) !voidptr {
		assert args.len == 0
		mut current_media := unsafe { &html.HTMLMediaElement(media_handle) }
		assert current_media.ready_state() == .have_metadata
		current_media.set_ready_state(.have_current_data)
		return actual_true
	})!
	queued_data_body := r'mdrOrder.push("reentrant-data");mdrSaved.push(event);mdrChecks.push(event.isTrusted&&this===mdrVideo&&this.readyState===2&&window.event===event);document.getElementById("mdr-result").textContent="reentrant media data painted";return false;'
	queued_metadata_body := r'mdrOrder.push("replacement-metadata");mdrSaved.push(event);mdrChecks.push(event.isTrusted&&this===mdrVideo&&this.readyState===1&&window.event===event);this.setAttribute("onloadeddata",mdrQueuedDataBody);void this.paused;mdrChecks.push(__mediaDataRawAdvance());this.onloadedmetadata=mdrMetadataIDL;return false;'
	assert runtime.evaluate_host('globalThis.mdrQueuedDataBody=${json2.encode(queued_data_body)};mdrVideo.setAttribute("onloadedmetadata",${json2.encode(queued_metadata_body)});mdrVideo.paused&&mdrVideo.readyState===1&&mdrOrder.length===0')! == 'true'
	assert metadata_slot.value.kind == .string && metadata_slot.value.string_data == queued_metadata_body
	// The already queued metadata task picks up the replacement body. That
	// callback replaces loadeddata and crosses metadata to current data while
	// the same owner context is active; the new task observes the latest body.
	media_data_raw_owner_drain(document)
	assert media.ready_state() == .have_current_data && media.paused()
	assert runtime.evaluate_host('mdrOrder.join(",")==="replacement-metadata,reentrant-data"&&mdrSaved.length===2&&mdrSaved.every(event=>event.isTrusted&&event.defaultPrevented)&&mdrChecks.length===3&&mdrChecks.every(Boolean)&&mdrVideo.onloadedmetadata===mdrMetadataIDL&&mdrVideo.onloadeddata!==mdrSecondData&&window.event===undefined')! == 'true'
	reentrant_data := native_video.get_current_value_of_event_handler('loadeddata') or { panic('Reentrant data callback missing') }
	assert reentrant_data.compiled_source_text_ == 'function onloadeddata(event) {\n${queued_data_body}\n}'
	assert voidptr(data_slot.listener or { panic('Reentrant data listener missing') }) == voidptr(data_listener)
	assert media.event_count('loadedmetadata') == 1 && media.event_count('loadeddata') == 1
	// A later metadata-to-current crossing in the same load has consumed its
	// first-data flag. A new explicit load rearms it and queues fresh metadata.
	media.set_ready_state(.have_metadata)
	media.set_ready_state(.have_current_data)
	assert media_data_raw_owner_take_task(document) == none
	assert runtime.evaluate_host('mdrOrder.length===2')! == 'true'
	assert runtime.evaluate_host(r'
mdrVideo.onloadedmetadata=mdrMetadataIDL;mdrVideo.onloadeddata=mdrDataIDL;mdrVideo.removeAttribute("onloadedmetadata");mdrVideo.removeAttribute("onloadeddata");mdrVideo.onloadedmetadata===null&&mdrVideo.onloadeddata===null
')! == 'true'
	assert !native_video.data.has_event_handler('loadedmetadata') && !native_video.data.has_event_handler('loadeddata')
	assert video.get_attribute('onloadedmetadata') == none && video.get_attribute('onloadeddata') == none
	assert runtime.evaluate_host(r'
mdrVideo.onloadedmetadata=mdrMetadataIDL;mdrVideo.onloadeddata=mdrDataIDL;mdrVideo.removeAttribute("onloadedmetadata");mdrVideo.removeAttribute("onloadeddata");mdrVideo.load();mdrVideo.onloadedmetadata===mdrMetadataIDL&&mdrVideo.onloadeddata===mdrDataIDL&&mdrVideo.readyState===1&&mdrOrder.length===2
')! == 'true'
	media_data_raw_owner_drain(document)
	assert runtime.evaluate_host('mdrOrder.join(",")==="replacement-metadata,reentrant-data,idl-metadata"&&mdrChecks.every(Boolean)')! == 'true'
	media.set_ready_state(.have_current_data)
	media_data_raw_owner_drain(document)
	assert runtime.evaluate_host('mdrOrder.join(",")==="replacement-metadata,reentrant-data,idl-metadata,idl-data"&&mdrChecks.length===5&&mdrChecks.every(Boolean)&&mdrSaved.length===4&&mdrSaved.every(event=>event.isTrusted&&event.defaultPrevented)&&mdrVideo.onloadedmetadata===mdrMetadataIDL&&mdrVideo.onloadeddata===mdrDataIDL&&window.event===undefined')! == 'true'
	assert native_video.event_listener_list().len == 2
	assert media.event_count('loadedmetadata') == 2 && media.event_count('loadeddata') == 2
	for index in 0 .. 4 {
		event := runtime.native_event(runtime.evaluate_host_value('mdrSaved[${index}]')!)!
		media_data_raw_owner_event(mut runtime, event, 'mdrSaved[${index}]')!
	}
	app.poll_javascript_tasks()
	assert document.get_element_by_id('mdr-result')?.text_content()? == 'reentrant media data painted'
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'reentrant media data painted').len > 0
	assert app.js_messages == []
	media_data_raw_owner_balance(runtime, document, 0)
}

fn test_media_raw_data_scripting_gate_strict_original_exception_and_later_owner_listener() {
	$if !darwin { return }
	mut app, mut document, mut runtime := media_data_raw_owner_fixture(media_data_raw_owner_markup, r'
globalThis.mdrVideo=document.getElementById("mdr-video");globalThis.mdrRuns=0;globalThis.mdrDataRuns=0;globalThis.mdrChecks=[];globalThis.mdrSaved=[];globalThis.mdrReason={original:true};globalThis.mdrOrder=[];mdrVideo.event={sentinel:true};document.event={sentinel:true};0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	media_data_raw_owner_probe(mut runtime, document)!
	video := document.get_element_by_id('mdr-video')?
	native_video := unsafe { &dom.EventTarget(video) }
	mut media := media_data_raw_owner_configure(video)!
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	body := r'"use strict";mdrRuns++;mdrOrder.push("strict-metadata");mdrSaved.push(event);mdrChecks.push(arguments.length===1&&event===arguments[0]&&this===mdrVideo&&event.target===mdrVideo&&event.currentTarget===mdrVideo&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event&&this.readyState===1&&__mediaDataRawOwnerContext());try{void arguments.callee;mdrChecks.push(false)}catch(error){mdrChecks.push(error instanceof TypeError)}this.onloadedmetadata=null;globalThis.mdrLiveName=onloadedmetadata;throw mdrReason;'
	data_body := r'mdrDataRuns++;mdrOrder.push("raw-data");mdrSaved.push(event);mdrChecks.push(event.isTrusted&&this===mdrVideo&&window.event===event&&this.readyState===2&&__mediaDataRawOwnerContext());return false;'
	// Synchronize through the compact state before capturing native slots.
	assert runtime.evaluate_host('mdrVideo.setAttribute("onloadedmetadata",${json2.encode(body)});mdrVideo.setAttribute("onloadeddata",${json2.encode(data_body)});mdrVideo.paused')! == 'true'
	metadata_slot := native_video.data.event_handler('loadedmetadata') or { panic('Strict metadata slot missing') }
	data_slot := native_video.data.event_handler('loadeddata') or { panic('Raw data slot missing') }
	mut owner := app.page_model
	owner.set_is_scripting_enabled(false)
	assert runtime.evaluate_host(r'mdrVideo.src="/gated-data.mp4";mdrVideo.load();mdrVideo.readyState===1&&mdrVideo.onloadedmetadata===null&&mdrVideo.onloadeddata===null&&mdrRuns===0&&mdrDataRuns===0')! == 'true'
	media_data_raw_owner_drain(document)
	media.set_ready_state(.have_current_data)
	media_data_raw_owner_drain(document)
	assert metadata_slot.value.kind == .string && metadata_slot.value.string_data == body
	assert data_slot.value.kind == .string && data_slot.value.string_data == data_body
	assert media.event_count('loadedmetadata') == 1 && media.event_count('loadeddata') == 1
	assert runtime.evaluate_host('mdrRuns===0&&mdrDataRuns===0&&mdrSaved.length===0&&mdrOrder.length===0')! == 'true'
	media_data_raw_owner_balance(runtime, document, 0)
	owner.set_is_scripting_enabled(true)
	assert runtime.evaluate_host(r'
globalThis.mdrStrict=mdrVideo.onloadedmetadata;globalThis.mdrData=mdrVideo.onloadeddata;
mdrVideo.addEventListener("loadedmetadata",function(event){mdrOrder.push("later-metadata");globalThis.mdrLater=this===mdrVideo&&event.currentTarget===mdrVideo&&event.isTrusted&&!event.defaultPrevented&&window.event===event&&this.readyState===1;document.getElementById("mdr-result").textContent="later media metadata listener"});typeof mdrStrict==="function"&&mdrStrict.name==="onloadedmetadata"&&mdrStrict.length===1&&mdrVideo.onloadedmetadata===mdrStrict&&typeof mdrData==="function"&&mdrData.name==="onloadeddata"&&mdrVideo.onloadeddata===mdrData&&mdrRuns===0
')! == 'true'
	strict_callback := native_video.get_current_value_of_event_handler('loadedmetadata') or { panic('Strict metadata callback missing') }
	assert strict_callback.compiled_source_text_ == 'function onloadedmetadata(event) {\n${body}\n}'
	assert runtime.javascript_event_handler(native_video, 'loadedmetadata')! == runtime.evaluate_host_value('mdrStrict')!
	assert runtime.evaluate_host('mdrVideo.load();mdrVideo.readyState===1&&mdrOrder.length===0')! == 'true'
	media_data_raw_owner_drain(document)
	assert runtime.evaluate_host('mdrOrder.join(",")==="strict-metadata,later-metadata"&&mdrRuns===1&&mdrDataRuns===0&&mdrLiveName===null&&mdrVideo.onloadedmetadata===null&&mdrLater&&mdrChecks.length===2&&mdrChecks.every(Boolean)&&window.event===undefined')! == 'true'
	assert !native_video.data.has_event_handler('loadedmetadata') && native_video.data.has_event_handler('loadeddata')
	assert video.get_attribute_value('onloadedmetadata') == body && video.get_attribute_value('onloadeddata') == data_body
	assert settings.realm().reported_exceptions.len == 1
	reported := settings.realm().reported_exceptions[0].value.as_webidl_value()!
	assert runtime.actual_webidl_value(reported)! == runtime.evaluate_host_value('mdrReason')!
	media.set_ready_state(.have_current_data)
	media_data_raw_owner_drain(document)
	assert runtime.evaluate_host('mdrRuns===1&&mdrDataRuns===1&&mdrChecks.length===3&&mdrChecks.every(Boolean)&&mdrVideo.onloadeddata===mdrData&&mdrSaved.length===2&&!mdrSaved[0].defaultPrevented&&mdrSaved[1].defaultPrevented&&mdrOrder.join(",")==="strict-metadata,later-metadata,raw-data"&&window.event===undefined')! == 'true'
	assert media.event_count('loadedmetadata') == 2 && media.event_count('loadeddata') == 2
	for index in 0 .. 2 {
		event := runtime.native_event(runtime.evaluate_host_value('mdrSaved[${index}]')!)!
		media_data_raw_owner_event(mut runtime, event, 'mdrSaved[${index}]')!
	}
	app.poll_javascript_tasks()
	assert document.get_element_by_id('mdr-result')?.text_content()? == 'later media metadata listener'
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'later media metadata listener').len > 0
	assert app.js_messages == []
	media_data_raw_owner_balance(runtime, document, 1)
}

