module main

import browserjs
import dom
import html
import math
import page
import time

const mcr_owner_first = 'urn:media-controls-replay-first'
const mcr_owner_second = 'urn:media-controls-replay-second'

@[heap]
struct McrOwnerProbe {
mut:
	fetches int
	starts int
	getter_saw_outer bool
}

fn mcr_owner_element(document &dom.Document, id string) !&dom.Element {
	return document.get_element_by_id(id) or { return error('Missing media namespace replay element ${id}') }
}

fn mcr_owner_attr(element &dom.Element, namespace ?string, local_name string) !&dom.Attr_ {
	return element.get_attribute_node_ns(namespace, local_name) or { return error('Missing media namespace replay attribute ${local_name}') }
}

fn mcr_owner_fixture() !(&BrowserApp, &dom.Document, &browserjs.Runtime) {
	mut owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><style>html,body{margin:0}video{width:100px;height:40px}</style><video id="mcr-video"></video><audio id="mcr-audio"></audio><audio id="mcr-resource" preload="none"></audio>', dom.URL{
		value: 'https://media-controls-replay.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	for index, id in ['mcr-video', 'mcr-audio'] {
		mut element := mcr_owner_element(document, id)!
		if index == 1 { element.set_attribute_value('controls', 'initial null') }
		element.set_attribute_ns_for_bindings(mcr_owner_first, 'controls', 'first foreign ${id}')!
		if index == 0 { element.set_attribute_value('controls', 'initial null') }
		element.set_attribute_ns_for_bindings(mcr_owner_second, 'controls', 'second foreign ${id}')!
	}
	mut resource := mcr_owner_element(document, 'mcr-resource')!
	resource.set_attribute_ns_for_bindings(mcr_owner_first, 'preload', 'foreign preload raw')!
	runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'globalThis.mcrVideo=document.getElementById("mcr-video");globalThis.mcrAudio=document.getElementById("mcr-audio");globalThis.mcrResource=document.getElementById("mcr-resource");void mcrVideo.controls;void mcrAudio.controls;void mcrResource.paused;0'], runtime, mut messages)
	assert messages == []
	app := &BrowserApp{ page_model: owner, document: document, js_runtime: runtime, viewport_width: 320, viewport_height: 240 }
	return app, document, runtime
}

fn mcr_owner_flush(document &dom.Document, runtime &browserjs.Runtime) ! {
	snapshot := runtime.evaluate_host('__ladybirdFinalize()')!
	mut messages := []string{}
	apply_javascript_state(document, snapshot, runtime.canvas_elements_for_binding(), mut messages)
	assert messages == []
	_ = runtime.evaluate_host('__ladybirdClearLogs();0')!
}

fn mcr_owner_drain(document &dom.Document) {
	mut queue := html.main_thread_event_loop().task_queue()
	mut count := 0
	for {
		task := queue.take_first_runnable_matching(fn [document] (item &html.Task) bool {
			owner := item.document() or { return false }
			return item.source() == .media_element && voidptr(owner) == voidptr(document)
		}) or { break }
		count++
		assert count < 100
		task.execute()
	}
}

fn mcr_owner_balance(app &BrowserApp, document &dom.Document, runtime &browserjs.Runtime) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0 && runtime.libjs_vm().interpreter_stack().depth() == 0
	assert app.js_messages == []
}

fn test_native_controls_owner_replay_preserves_foreign_duplicates_after_null_namespace_removal() {
	$if !darwin { return }
	mut app, mut document, mut runtime := mcr_owner_fixture()!
	defer { runtime.close(); document.finalize() }
	video := mcr_owner_element(document, 'mcr-video')!
	audio := mcr_owner_element(document, 'mcr-audio')!
	probe := &McrOwnerProbe{}
	for index, element in [video, audio] {
		name := if index == 0 { 'mcrVideo' } else { 'mcrAudio' }
		id := if index == 0 { 'mcr-video' } else { 'mcr-audio' }
		first := mcr_owner_attr(element, mcr_owner_first, 'controls')!
		second := mcr_owner_attr(element, mcr_owner_second, 'controls')!
		null_attr := mcr_owner_attr(element, none, 'controls')!
		mut media := html.html_media_element_for_dom_element(element) or { panic('Missing media replay model') }
		media.set_fetch_hook(fn [probe] (_ dom.URL, _ u64) !html.MediaResourceResponse {
			mut observed := unsafe { &McrOwnerProbe(probe) }
			observed.fetches++
			return error('controls replay must not fetch')
		})
		assert runtime.evaluate_host('${name}.controls===true')! == 'true'
		assert runtime.evaluate_host('${name}.controls=true;${name}.controls=false;!${name}.controls&&${name}.hasAttribute("controls")&&${name}.getAttribute("controls")==="first foreign ${id}"')! == 'true'
		assert runtime.evaluate_host('${name}.setAttribute("data-dirty","survives foreign controls");document.querySelector("#${id}")===${name}&&!${name}.controls')! == 'true'
		mcr_owner_flush(document, runtime)!
		assert !element.has_attribute_ns(none, 'controls') && null_attr.owner_element() == none
		assert voidptr(mcr_owner_attr(element, mcr_owner_first, 'controls')!) == voidptr(first)
		assert voidptr(mcr_owner_attr(element, mcr_owner_second, 'controls')!) == voidptr(second)
		assert first.value() == 'first foreign ${id}' && second.value() == 'second foreign ${id}'
		assert element.get_attribute_names().filter(it == 'controls').len == 2
		assert runtime.evaluate_host('${name}.controls=true;${name}.controls&&${name}.getAttribute("controls")==="first foreign ${id}"')! == 'true'
		new_null := mcr_owner_attr(element, none, 'controls')!
		assert new_null.value() == '' && voidptr(new_null) != voidptr(null_attr)
		assert runtime.evaluate_host('${name}.controls=false;${name}.setAttribute("data-dirty","second removal");!${name}.controls&&${name}.getAttribute("controls")==="first foreign ${id}"')! == 'true'
		mcr_owner_flush(document, runtime)!
		assert !element.has_attribute_ns(none, 'controls') && new_null.owner_element() == none
		assert voidptr(mcr_owner_attr(element, mcr_owner_first, 'controls')!) == voidptr(first)
		assert voidptr(mcr_owner_attr(element, mcr_owner_second, 'controls')!) == voidptr(second)
		assert first.value() == 'first foreign ${id}' && second.value() == 'second foreign ${id}'
		assert media.paused() && media.current_time() == 0 && !media.has_controls()
		assert media.current_src() == '' && media.network_state() == .empty && media.ready_state() == .have_nothing
		assert math.is_nan(media.duration()) && !media.muted() && media.volume() == 1
		for event in ['loadstart', 'play', 'pause', 'volumechange'] { assert media.event_count(event) == 0 }
	}
	// This is the first layout; no existing-widget teardown behavior is exercised.
	app.relayout(320, 240 + app.chrome_height())
	assert video.shadow_root() == none && audio.shadow_root() == none
	assert audio.as_node().unsafe_layout_node() == none && probe.fetches == 0
	mcr_owner_balance(app, document, runtime)
}

fn test_native_media_namespace_sync_survives_poisoned_intrinsics_and_preserves_reentrant_raw_preload() {
	$if !darwin { return }
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.block_audio_and_video, [])
	mut app, mut document, mut runtime := mcr_owner_fixture()!
	defer { runtime.close(); document.finalize() }
	video := mcr_owner_element(document, 'mcr-video')!
	first := mcr_owner_attr(video, mcr_owner_first, 'controls')!
	second := mcr_owner_attr(video, mcr_owner_second, 'controls')!
	assert runtime.evaluate_host(r'(()=>{
 globalThis.mcrPoisonCalls=0;const define=Object.defineProperty,remove=Reflect.deleteProperty;
 const saved={own:Object.getOwnPropertyDescriptors(mcrVideo),get:mcrVideo.getAttribute,has:mcrVideo.hasAttribute,set:mcrVideo.setAttribute,remove:mcrVideo.removeAttribute,define:define,apply:Reflect.apply,delete:remove,weakGet:WeakMap.prototype.get,weakSet:WeakMap.prototype.set,boolean:Boolean,sync:globalThis.__ladybirdMediaElementSetAttributeSync};
 const descriptor=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"controls"),poison=function(){mcrPoisonCalls++;throw "author poison"};
 for(const name of ["getAttribute","hasAttribute","setAttribute","removeAttribute"])define(mcrVideo,name,{get:poison,configurable:true});
 define(globalThis,"__ladybirdMediaElementSetAttributeSync",{value:poison,configurable:true});define(Object.prototype,"controls",{get:poison,set:poison,configurable:true});
 globalThis.Boolean=poison;WeakMap.prototype.get=poison;WeakMap.prototype.set=poison;Reflect.apply=poison;Reflect.deleteProperty=poison;Object.defineProperty=poison;
 try {
  descriptor.set.call(mcrVideo,{[Symbol.toPrimitive]:poison});if(descriptor.get.call(mcrVideo)!==true)return false;
  descriptor.set.call(mcrVideo,false);if(descriptor.get.call(mcrVideo)!==false)return false;
  return saved.has.call(mcrVideo,"controls")&&saved.get.call(mcrVideo,"controls")==="first foreign mcr-video"&&mcrPoisonCalls===0;
 } finally {
  saved.delete(Object.prototype,"controls");Object.defineProperty=saved.define;Reflect.apply=saved.apply;Reflect.deleteProperty=saved.delete;WeakMap.prototype.get=saved.weakGet;WeakMap.prototype.set=saved.weakSet;globalThis.Boolean=saved.boolean;
  saved.define(globalThis,"__ladybirdMediaElementSetAttributeSync",{value:saved.sync,configurable:true});for(const name of ["getAttribute","hasAttribute","setAttribute","removeAttribute"])saved.define(mcrVideo,name,saved.own[name]);
 }
})()')! == 'true'
	assert runtime.evaluate_host('mcrVideo.setAttribute("data-dirty","after poison");document.querySelector("#mcr-video")===mcrVideo&&!mcrVideo.controls')! == 'true'
	assert !video.has_attribute_ns(none, 'controls')
	assert voidptr(mcr_owner_attr(video, mcr_owner_first, 'controls')!) == voidptr(first)
	assert voidptr(mcr_owner_attr(video, mcr_owner_second, 'controls')!) == voidptr(second)
	assert first.value() == 'first foreign mcr-video' && second.value() == 'second foreign mcr-video'
	resource := mcr_owner_element(document, 'mcr-resource')!
	foreign_preload := mcr_owner_attr(resource, mcr_owner_first, 'preload')!
	mut media := html.html_media_element_for_dom_element(resource) or { panic('Missing resource replay model') }
	probe := &McrOwnerProbe{}
	runtime_handle := voidptr(runtime)
	media.set_fetch_hook(fn [probe, runtime_handle] (url dom.URL, offset u64) !html.MediaResourceResponse {
		mut observed := unsafe { &McrOwnerProbe(probe) }
		mut current_runtime := unsafe { &browserjs.Runtime(runtime_handle) }
		assert url.serialize() == 'https://media-controls-replay.example.test/resource.webm' && offset == 0
		observed.fetches++
		observed.getter_saw_outer = current_runtime.evaluate_host('mcrResource.preload==="metadata"&&mcrResource.getAttribute("preload")==="metadata"')! == 'true'
		assert observed.getter_saw_outer
		assert current_runtime.evaluate_host('mcrResource.preload="none";mcrResource.setAttribute("data-reentrant","inner none");mcrResource.paused&&mcrResource.preload==="none"&&mcrResource.getAttribute("preload")==="none"')! == 'true'
		return html.MediaResourceResponse{ mime_type: 'audio/webm', duration: 5, buffered_end: 5 }
	})
	media.set_playback_manager_hooks(html.MediaPlaybackManagerHooks{
		play: fn [probe] () {
			mut observed := unsafe { &McrOwnerProbe(probe) }
			observed.starts++
		}
	})
	assert runtime.evaluate_host('mcrResource.preload="none";mcrResource.src="/resource.webm";mcrResource.paused&&mcrResource.preload==="none"&&mcrResource.readyState===0')! == 'true'
	assert probe.fetches == 0 && media.network_state() == .idle
	assert runtime.evaluate_host('mcrResource.preload="metadata";mcrResource.paused&&mcrResource.preload==="none"&&mcrResource.readyState===4')! == 'true'
	assert probe.fetches == 1 && probe.starts == 0 && probe.getter_saw_outer
	assert runtime.evaluate_host('mcrResource.setAttribute("data-dirty","after outer return");document.querySelector("#mcr-resource")===mcrResource&&mcrResource.preload==="none"&&mcrResource.getAttribute("preload")==="none"')! == 'true'
	mcr_owner_flush(document, runtime)!
	assert resource.get_attribute_ns(none, 'preload')? == 'none'
	assert voidptr(mcr_owner_attr(resource, mcr_owner_first, 'preload')!) == voidptr(foreign_preload)
	assert foreign_preload.value() == 'foreign preload raw' && resource.get_attribute('data-reentrant')? == 'inner none'
	mcr_owner_drain(document)
	assert probe.fetches == 1 && probe.starts == 0 && media.paused()
	assert media.event_count('play') == 0 && media.event_count('playing') == 0
	mcr_owner_balance(app, document, runtime)
}
