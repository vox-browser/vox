module main

import browserjs
import dom
import html
import json2
import page
import time

const media_settings_raw_owner_markup = '<!doctype html><style>
html,body{margin:0}#msr-video{display:block;width:180px;height:60px}
#msr-result{position:absolute;top:100px;left:0}
</style><form id="msr-form"><video id="msr-video"></video></form><div id="msr-result">waiting</div>'

@[heap]
struct MediaSettingsRawOwnerObservation {
mut:
	events []&dom.Event
	targets []voidptr
}

fn media_settings_raw_owner_fixture(markup string, source string) !(&BrowserApp, &dom.Document, &browserjs.Runtime) {
	mut owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{
		value: 'https://media-settings-raw-owner.example.test/'
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

fn media_settings_raw_owner_take_task(document &dom.Document) ?&html.Task {
	mut queue := html.main_thread_event_loop().task_queue()
	return queue.take_first_runnable_matching(fn [document] (task &html.Task) bool {
		owner := task.document() or { return false }
		return task.source() == .media_element && voidptr(owner) == voidptr(document)
	})
}

fn media_settings_raw_owner_drain(document &dom.Document) {
	mut count := 0
	for {
		task := media_settings_raw_owner_take_task(document) or { break }
		count++
		assert count < 100
		task.execute()
	}
}

fn media_settings_raw_owner_probe(mut runtime browserjs.Runtime, document &dom.Document) ! {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	handle := voidptr(&runtime)
	actual_true := runtime.evaluate_host_value('true')!
	runtime.define_value_host_function('__mediaSettingsRawOwnerContext', fn [settings, handle, actual_true] (_ voidptr, args []voidptr) !voidptr {
		owner := unsafe { &browserjs.Runtime(handle) }
		assert args.len == 0
		assert settings.realm().script_execution_depth > 0 && settings.realm().callback_execution_depth > 0
		assert owner.libjs_vm().has_running_execution_context()
		assert voidptr(html.current_principal_settings_object()) == voidptr(settings)
		assert voidptr(html.incumbent_settings_object()) == voidptr(settings)
		return actual_true
	})!
}

fn media_settings_raw_owner_observe(element &dom.Element, observation &MediaSettingsRawOwnerObservation) {
	handle := voidptr(observation)
	callback := &dom.CallbackType{
		handle_event: fn [handle] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut saved := unsafe { &MediaSettingsRawOwnerObservation(handle) }
			assert event.type_name() in ['ratechange', 'volumechange']
			assert event.interface_ == .event && event.is_trusted()
			// The handler algorithm applies exact false to the canceled flag,
			// including native settings events whose cancelable flag is false.
			assert !event.bubbles() && !event.cancelable() && event.default_prevented()
			saved.events << event
			saved.targets << voidptr(event.target() or { panic('Native settings event needs its owner') })
			return dom.js_undefined()
		}
	}
	for name in ['ratechange', 'volumechange'] {
		unsafe { &dom.EventTarget(element) }.add_event_listener_without_options(name, dom.IDLEventListener.create(callback))
	}
}

fn media_settings_raw_owner_event(mut runtime browserjs.Runtime, event &dom.Event, expression string) ! {
	wrapper := runtime.evaluate_host_value(expression)!
	assert voidptr(runtime.native_event(wrapper)!) == voidptr(event)
	assert runtime.javascript_event(event)! == wrapper
	assert event.is_trusted() && event.current_target() == none && event.event_phase() == 0
	assert runtime.evaluate_host('${expression}.currentTarget===null&&${expression}.eventPhase===Event.NONE&&window.event===undefined')! == 'true'
}

fn media_settings_raw_owner_balance(runtime &browserjs.Runtime, document &dom.Document, exceptions int) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == exceptions
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_media_raw_ratechange_volumechange_parsed_created_scopes_trusted_events_and_live_values() {
	$if !darwin { return }
	body := r'msrRuns++;msrOrder.push(this.id+":"+event.type);msrScopes.push(scopeKey);delete this.scopeKey;msrScopes.push(scopeKey);delete document.scopeKey;msrScopes.push(scopeKey);document.scopeKey="document";this.scopeKey=this.id==="msr-video"?"parsed element":"created element";msrSaved.push(event);msrChecks.push(arguments.length===1&&event===arguments[0]&&(this===msrVideo||this===msrAudio)&&event.target===this&&event.currentTarget===this&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event&&document===msrDocument&&getElementById("msr-result")===msrResult&&defaultPlaybackRate===3&&playbackRate===0.5&&volume===0.75&&muted===true&&paused===true&&__mediaSettingsRawOwnerContext());getElementById("msr-result").textContent="raw media settings painted";this.style.color="rgb(0,128,0)";return false;'
	attribute_body := body.replace('"', '&quot;')
	markup := media_settings_raw_owner_markup.replace('<video id="msr-video">',
		'<video id="msr-video" onratechange="${attribute_body}" onvolumechange="${attribute_body}">')
	mut app, mut document, mut runtime := media_settings_raw_owner_fixture(markup, r'
globalThis.msrVideo=document.getElementById("msr-video");globalThis.msrDocument=document;globalThis.msrResult=document.getElementById("msr-result");globalThis.msrForm=document.getElementById("msr-form");
globalThis.msrRuns=0;globalThis.msrOrder=[];globalThis.msrScopes=[];globalThis.msrSaved=[];globalThis.msrChecks=[];globalThis.scopeKey="global";
document.scopeKey="document";msrForm.scopeKey="nearest form";msrVideo.scopeKey="parsed element";msrVideo.event={sentinel:true};document.event={sentinel:true};
globalThis.msrAudio=document.createElement("audio");msrAudio.id="msr-audio";msrAudio.setAttribute("onratechange",msrVideo.getAttribute("onratechange"));msrAudio.setAttribute("onvolumechange",msrVideo.getAttribute("onvolumechange"));document.body.appendChild(msrAudio);msrAudio.scopeKey="created element";void msrAudio.paused;0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	media_settings_raw_owner_probe(mut runtime, document)!
	video := document.get_element_by_id('msr-video')?
	audio := document.get_element_by_id('msr-audio')?
	native_video := unsafe { &dom.EventTarget(video) }
	native_audio := unsafe { &dom.EventTarget(audio) }
	for target in [native_video, native_audio] {
		for name in ['ratechange', 'volumechange'] {
			slot := target.data.event_handler(name) or { panic('Raw settings slot missing') }
			assert slot.value.kind == .string && slot.value.string_data == body
		}
	}
	assert runtime.evaluate_host(r'
globalThis.msrVideoRate=msrVideo.onratechange;globalThis.msrVideoVolume=msrVideo.onvolumechange;globalThis.msrAudioRate=msrAudio.onratechange;globalThis.msrAudioVolume=msrAudio.onvolumechange;
[msrVideoRate,msrVideoVolume,msrAudioRate,msrAudioVolume].every(value=>typeof value==="function"&&value.length===1)&&msrVideoRate.name==="onratechange"&&msrAudioRate.name==="onratechange"&&msrVideoVolume.name==="onvolumechange"&&msrAudioVolume.name==="onvolumechange"&&new Set([msrVideoRate,msrVideoVolume,msrAudioRate,msrAudioVolume]).size===4&&msrVideo.onratechange===msrVideoRate&&msrVideo.onvolumechange===msrVideoVolume&&msrAudio.onratechange===msrAudioRate&&msrAudio.onvolumechange===msrAudioVolume&&!Object.hasOwn(msrVideo,"onratechange")&&!Object.hasOwn(msrAudio,"onvolumechange")&&msrRuns===0
')! == 'true'
	for target in [native_video, native_audio] {
		for name in ['ratechange', 'volumechange'] {
			callback := target.get_current_value_of_event_handler(name) or { panic('Cached settings callback missing') }
			assert callback.compiled_source_text_ == 'function on${name}(event) {\n${body}\n}'
			alias := if voidptr(target) == voidptr(native_video) { 'msrVideo' } else { 'msrAudio' }
			assert runtime.javascript_event_handler(target, name)! == runtime.evaluate_host_value('${alias}.on${name}')!
		}
	}
	observation := &MediaSettingsRawOwnerObservation{}
	media_settings_raw_owner_observe(video, observation)
	media_settings_raw_owner_observe(audio, observation)
	// Each changed native setter queues one task. Interleaved rate and volume
	// changes retain queue order, while all handlers read the final live values.
	assert runtime.evaluate_host(r'
globalThis.msrRejected=[];
for(var msrElement of [msrVideo,msrAudio]){
msrElement.defaultPlaybackRate=2;msrElement.volume=0.5;msrElement.playbackRate=0.5;msrElement.muted=true;msrElement.defaultPlaybackRate=3;msrElement.volume=0.75;
msrElement.defaultPlaybackRate=3;msrElement.playbackRate=0.5;msrElement.volume=0.75;msrElement.muted=true;
try{msrElement.playbackRate=65;msrRejected.push(false)}catch(error){msrRejected.push(error instanceof DOMException&&error.name==="NotSupportedError")}
try{msrElement.volume=2;msrRejected.push(false)}catch(error){msrRejected.push(error instanceof DOMException&&error.name==="IndexSizeError")}
}
msrRuns===0&&msrSaved.length===0&&msrOrder.length===0&&msrRejected.length===4&&msrRejected.every(Boolean)&&msrVideo.paused&&msrAudio.paused
')! == 'true'
	media_settings_raw_owner_drain(document)
	assert media_settings_raw_owner_take_task(document) == none
	assert runtime.evaluate_host(r'
msrRuns===12&&msrOrder.join(",")==="msr-video:ratechange,msr-video:volumechange,msr-video:ratechange,msr-video:volumechange,msr-video:ratechange,msr-video:volumechange,msr-audio:ratechange,msr-audio:volumechange,msr-audio:ratechange,msr-audio:volumechange,msr-audio:ratechange,msr-audio:volumechange"&&msrScopes.join(",")===[...Array(6).fill("parsed element,document,global"),...Array(6).fill("created element,document,global")].join(",")&&msrChecks.length===12&&msrChecks.every(Boolean)&&msrSaved.every(event=>event.defaultPrevented)&&msrForm.scopeKey==="nearest form"&&msrVideo.onratechange===msrVideoRate&&msrVideo.onvolumechange===msrVideoVolume&&msrAudio.onratechange===msrAudioRate&&msrAudio.onvolumechange===msrAudioVolume&&window.event===undefined
')! == 'true'
	assert observation.events.len == 12
	for index, event in observation.events {
		mut expected_target := voidptr(video)
		if index >= 6 {
			expected_target = voidptr(audio)
		}
		assert observation.targets[index] == expected_target
		media_settings_raw_owner_event(mut runtime, event, 'msrSaved[${index}]')!
	}
	video_media := html.html_media_element_for_dom_element(video) or { panic('Video settings owner missing') }
	audio_media := html.html_media_element_for_dom_element(audio) or { panic('Audio settings owner missing') }
	assert video_media.event_count('ratechange') == 3 && video_media.event_count('volumechange') == 3
	assert audio_media.event_count('ratechange') == 3 && audio_media.event_count('volumechange') == 3
	app.poll_javascript_tasks()
	assert document.get_element_by_id('msr-result')?.text_content()? == 'raw media settings painted'
	assert video.get_attribute_value('style').contains('color') && audio.get_attribute_value('style').contains('color')
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'raw media settings painted').len > 0
	assert app.js_messages == []
	media_settings_raw_owner_balance(runtime, document, 0)
}

fn test_media_raw_settings_live_equal_attributes_prequeued_reentrant_replacement_and_removal() {
	$if !darwin { return }
	body := r'msrOrder.push("original-"+event.type);msrSaved.push(event);return false;'
	attribute_body := body.replace('"', '&quot;')
	markup := media_settings_raw_owner_markup.replace('<video id="msr-video">',
		'<video id="msr-video" onratechange="${attribute_body}" onvolumechange="${attribute_body}">')
	mut app, mut document, mut runtime := media_settings_raw_owner_fixture(markup, r'
globalThis.msrVideo=document.getElementById("msr-video");globalThis.msrOrder=[];globalThis.msrSaved=[];globalThis.msrChecks=[];globalThis.msrSource=msrVideo.getAttribute("onratechange");globalThis.msrFirstRate=msrVideo.onratechange;globalThis.msrFirstVolume=msrVideo.onvolumechange;
globalThis.msrRateIDL=function(event){msrOrder.push("idl-rate");msrSaved.push(event);msrChecks.push(this===msrVideo&&event.isTrusted&&window.event===event);return false};
globalThis.msrVolumeIDL=function(event){msrOrder.push("idl-volume");msrSaved.push(event);msrChecks.push(this===msrVideo&&event.isTrusted&&window.event===event);return false};0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	video := document.get_element_by_id('msr-video')?
	native_video := unsafe { &dom.EventTarget(video) }
	rate_slot := native_video.data.event_handler('ratechange') or { panic('Rate slot missing') }
	volume_slot := native_video.data.event_handler('volumechange') or { panic('Volume slot missing') }
	rate_listener := rate_slot.listener or { panic('Rate listener missing') }
	volume_listener := volume_slot.listener or { panic('Volume listener missing') }
	first_rate := native_video.get_current_value_of_event_handler('ratechange') or { panic('First rate callback missing') }
	first_volume := native_video.get_current_value_of_event_handler('volumechange') or { panic('First volume callback missing') }
	assert runtime.evaluate_host(r'
msrVideo.onratechange=msrRateIDL;msrVideo.setAttribute("onratechange",msrSource);globalThis.msrSecondRate=msrVideo.onratechange;
msrVideo.onvolumechange=msrVolumeIDL;msrVideo.setAttribute("onvolumechange",msrSource);globalThis.msrSecondVolume=msrVideo.onvolumechange;
typeof msrSecondRate==="function"&&msrSecondRate!==msrFirstRate&&msrSecondRate!==msrRateIDL&&msrSecondRate.name==="onratechange"&&msrSecondRate.length===1&&typeof msrSecondVolume==="function"&&msrSecondVolume!==msrFirstVolume&&msrSecondVolume!==msrVolumeIDL&&msrSecondVolume.name==="onvolumechange"&&msrSecondVolume.length===1&&msrVideo.onratechange===msrSecondRate&&msrVideo.onvolumechange===msrSecondVolume&&msrOrder.length===0
')! == 'true'
	assert voidptr(native_video.data.event_handler('ratechange') or { panic('Replaced rate slot missing') }) == voidptr(rate_slot)
	assert voidptr(native_video.data.event_handler('volumechange') or { panic('Replaced volume slot missing') }) == voidptr(volume_slot)
	assert voidptr(rate_slot.listener or { panic('Replaced rate listener missing') }) == voidptr(rate_listener)
	assert voidptr(volume_slot.listener or { panic('Replaced volume listener missing') }) == voidptr(volume_listener)
	second_rate := native_video.get_current_value_of_event_handler('ratechange') or { panic('Second rate callback missing') }
	second_volume := native_video.get_current_value_of_event_handler('volumechange') or { panic('Second volume callback missing') }
	assert voidptr(second_rate) != voidptr(first_rate) && second_rate.compiled_source_text_ == first_rate.compiled_source_text_
	assert voidptr(second_volume) != voidptr(first_volume) && second_volume.compiled_source_text_ == first_volume.compiled_source_text_
	assert runtime.evaluate_host('msrVideo.defaultPlaybackRate=2;msrVideo.volume=0.5;msrOrder.length===0')! == 'true'
	queued_volume_body := r'msrOrder.push("reentrant-volume");msrSaved.push(event);msrChecks.push(event.isTrusted&&this===msrVideo&&this.volume===0.75&&window.event===event);document.getElementById("msr-result").textContent="reentrant media settings painted";return false;'
	queued_rate_body := r'msrOrder.push("replacement-rate");msrSaved.push(event);msrChecks.push(event.isTrusted&&this===msrVideo&&this.defaultPlaybackRate===2&&window.event===event);this.setAttribute("onvolumechange",msrQueuedVolumeBody);void this.paused;this.volume=0.75;this.defaultPlaybackRate=3;msrChecks.push(msrSaved.length===1);this.onratechange=msrRateIDL;return false;'
	assert runtime.evaluate_host('globalThis.msrQueuedVolumeBody=${json2.encode(queued_volume_body)};msrVideo.setAttribute("onratechange",${json2.encode(queued_rate_body)});msrVideo.paused&&msrOrder.length===0')! == 'true'
	assert rate_slot.value.kind == .string && rate_slot.value.string_data == queued_rate_body
	// The queued rate task reads the replacement body. Its setters append tasks
	// behind the existing volume task and do not dispatch inside the callback.
	(media_settings_raw_owner_take_task(document) or { panic('Missing queued rate task') }).execute()
	assert runtime.evaluate_host('msrOrder.join(",")==="replacement-rate"&&msrSaved.length===1&&msrVideo.defaultPlaybackRate===3&&msrVideo.volume===0.75')! == 'true'
	media_settings_raw_owner_drain(document)
	assert runtime.evaluate_host('msrOrder.join(",")==="replacement-rate,reentrant-volume,reentrant-volume,idl-rate"&&msrSaved.length===4&&msrSaved.every(event=>event.isTrusted&&event.defaultPrevented)&&msrChecks.length===5&&msrChecks.every(Boolean)&&msrVideo.onratechange===msrRateIDL&&msrVideo.onvolumechange!==msrSecondVolume&&window.event===undefined')! == 'true'
	reentrant_volume := native_video.get_current_value_of_event_handler('volumechange') or { panic('Reentrant volume callback missing') }
	assert reentrant_volume.compiled_source_text_ == 'function onvolumechange(event) {\n${queued_volume_body}\n}'
	assert voidptr(volume_slot.listener or { panic('Reentrant volume listener missing') }) == voidptr(volume_listener)
	// Present attribute removal clears IDL replacements before queued delivery.
	assert runtime.evaluate_host(r'
msrVideo.defaultPlaybackRate=4;msrVideo.volume=0.25;msrVideo.onratechange=msrRateIDL;msrVideo.onvolumechange=msrVolumeIDL;msrVideo.removeAttribute("onratechange");msrVideo.removeAttribute("onvolumechange");msrVideo.onratechange===null&&msrVideo.onvolumechange===null&&msrOrder.length===4
')! == 'true'
	assert !native_video.data.has_event_handler('ratechange') && !native_video.data.has_event_handler('volumechange')
	assert video.get_attribute('onratechange') == none && video.get_attribute('onvolumechange') == none
	media_settings_raw_owner_drain(document)
	assert runtime.evaluate_host('msrOrder.length===4&&msrSaved.length===4')! == 'true'
	// Removing an already absent content attribute leaves later IDL values live.
	assert runtime.evaluate_host(r'
msrVideo.onratechange=msrRateIDL;msrVideo.onvolumechange=msrVolumeIDL;msrVideo.removeAttribute("onratechange");msrVideo.removeAttribute("onvolumechange");msrVideo.playbackRate=0.5;msrVideo.muted=true;msrVideo.onratechange===msrRateIDL&&msrVideo.onvolumechange===msrVolumeIDL&&msrOrder.length===4
')! == 'true'
	media_settings_raw_owner_drain(document)
	assert runtime.evaluate_host('msrOrder.join(",")==="replacement-rate,reentrant-volume,reentrant-volume,idl-rate,idl-rate,idl-volume"&&msrChecks.length===7&&msrChecks.every(Boolean)&&msrSaved.length===6&&msrSaved.every(event=>event.isTrusted&&event.defaultPrevented)&&msrVideo.onratechange===msrRateIDL&&msrVideo.onvolumechange===msrVolumeIDL&&window.event===undefined')! == 'true'
	assert native_video.event_listener_list().len == 2
	media := html.html_media_element_for_dom_element(video) or { panic('Settings media owner missing') }
	assert media.event_count('ratechange') == 4 && media.event_count('volumechange') == 4
	for index in 0 .. 6 {
		event := runtime.native_event(runtime.evaluate_host_value('msrSaved[${index}]')!)!
		media_settings_raw_owner_event(mut runtime, event, 'msrSaved[${index}]')!
	}
	app.poll_javascript_tasks()
	assert document.get_element_by_id('msr-result')?.text_content()? == 'reentrant media settings painted'
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'reentrant media settings painted').len > 0
	assert app.js_messages == []
	media_settings_raw_owner_balance(runtime, document, 0)
}

fn test_media_raw_settings_scripting_gate_strict_original_exception_and_later_owner_listener() {
	$if !darwin { return }
	mut app, mut document, mut runtime := media_settings_raw_owner_fixture(media_settings_raw_owner_markup, r'
globalThis.msrVideo=document.getElementById("msr-video");globalThis.msrRuns=0;globalThis.msrVolumeRuns=0;globalThis.msrChecks=[];globalThis.msrSaved=[];globalThis.msrReason={original:true};globalThis.msrOrder=[];msrVideo.event={sentinel:true};document.event={sentinel:true};0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	media_settings_raw_owner_probe(mut runtime, document)!
	video := document.get_element_by_id('msr-video')?
	native_video := unsafe { &dom.EventTarget(video) }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	body := r'"use strict";msrRuns++;msrOrder.push("strict-rate");msrSaved.push(event);msrChecks.push(arguments.length===1&&event===arguments[0]&&this===msrVideo&&event.target===msrVideo&&event.currentTarget===msrVideo&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event&&this.playbackRate===0.5&&__mediaSettingsRawOwnerContext());try{void arguments.callee;msrChecks.push(false)}catch(error){msrChecks.push(error instanceof TypeError)}this.onratechange=null;globalThis.msrLiveName=onratechange;throw msrReason;'
	volume_body := r'msrVolumeRuns++;msrOrder.push("raw-volume");msrSaved.push(event);msrChecks.push(event.isTrusted&&this===msrVideo&&window.event===event&&this.volume===0.5&&this.muted&&__mediaSettingsRawOwnerContext());return false;'
	assert runtime.evaluate_host('msrVideo.setAttribute("onratechange",${json2.encode(body)});msrVideo.setAttribute("onvolumechange",${json2.encode(volume_body)});msrVideo.paused')! == 'true'
	rate_slot := native_video.data.event_handler('ratechange') or { panic('Strict rate slot missing') }
	volume_slot := native_video.data.event_handler('volumechange') or { panic('Raw volume slot missing') }
	mut owner := app.page_model
	owner.set_is_scripting_enabled(false)
	assert runtime.evaluate_host('msrVideo.defaultPlaybackRate=2;msrVideo.volume=0.5;msrVideo.onratechange===null&&msrVideo.onvolumechange===null&&msrRuns===0&&msrVolumeRuns===0')! == 'true'
	media_settings_raw_owner_drain(document)
	assert rate_slot.value.kind == .string && rate_slot.value.string_data == body
	assert volume_slot.value.kind == .string && volume_slot.value.string_data == volume_body
	assert runtime.evaluate_host('msrRuns===0&&msrVolumeRuns===0&&msrSaved.length===0&&msrOrder.length===0')! == 'true'
	media_settings_raw_owner_balance(runtime, document, 0)
	owner.set_is_scripting_enabled(true)
	assert runtime.evaluate_host(r'
globalThis.msrStrict=msrVideo.onratechange;globalThis.msrVolume=msrVideo.onvolumechange;
msrVideo.addEventListener("ratechange",function(event){msrOrder.push("later-rate");globalThis.msrLater=this===msrVideo&&event.currentTarget===msrVideo&&event.isTrusted&&!event.defaultPrevented&&window.event===event&&this.playbackRate===0.5;document.getElementById("msr-result").textContent="later media rate listener"});typeof msrStrict==="function"&&msrStrict.name==="onratechange"&&msrStrict.length===1&&msrVideo.onratechange===msrStrict&&typeof msrVolume==="function"&&msrVolume.name==="onvolumechange"&&msrVideo.onvolumechange===msrVolume&&msrRuns===0
')! == 'true'
	strict_callback := native_video.get_current_value_of_event_handler('ratechange') or { panic('Strict rate callback missing') }
	assert strict_callback.compiled_source_text_ == 'function onratechange(event) {\n${body}\n}'
	assert runtime.javascript_event_handler(native_video, 'ratechange')! == runtime.evaluate_host_value('msrStrict')!
	assert runtime.evaluate_host('msrVideo.playbackRate=0.5;msrOrder.length===0')! == 'true'
	media_settings_raw_owner_drain(document)
	assert runtime.evaluate_host('msrOrder.join(",")==="strict-rate,later-rate"&&msrRuns===1&&msrVolumeRuns===0&&msrLiveName===null&&msrVideo.onratechange===null&&msrLater&&msrChecks.length===2&&msrChecks.every(Boolean)&&window.event===undefined')! == 'true'
	assert !native_video.data.has_event_handler('ratechange') && native_video.data.has_event_handler('volumechange')
	assert video.get_attribute_value('onratechange') == body && video.get_attribute_value('onvolumechange') == volume_body
	assert settings.realm().reported_exceptions.len == 1
	reported := settings.realm().reported_exceptions[0].value.as_webidl_value()!
	assert runtime.actual_webidl_value(reported)! == runtime.evaluate_host_value('msrReason')!
	assert runtime.evaluate_host('msrVideo.muted=true;msrVolumeRuns===0')! == 'true'
	media_settings_raw_owner_drain(document)
	assert runtime.evaluate_host('msrRuns===1&&msrVolumeRuns===1&&msrChecks.length===3&&msrChecks.every(Boolean)&&msrVideo.onvolumechange===msrVolume&&msrSaved.length===2&&!msrSaved[0].defaultPrevented&&msrSaved[1].defaultPrevented&&msrOrder.join(",")==="strict-rate,later-rate,raw-volume"&&window.event===undefined')! == 'true'
	media := html.html_media_element_for_dom_element(video) or { panic('Gated settings media owner missing') }
	assert media.event_count('ratechange') == 2 && media.event_count('volumechange') == 2
	for index in 0 .. 2 {
		event := runtime.native_event(runtime.evaluate_host_value('msrSaved[${index}]')!)!
		media_settings_raw_owner_event(mut runtime, event, 'msrSaved[${index}]')!
	}
	app.poll_javascript_tasks()
	assert document.get_element_by_id('msr-result')?.text_content()? == 'later media rate listener'
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'later media rate listener').len > 0
	assert app.js_messages == []
	media_settings_raw_owner_balance(runtime, document, 1)
}

