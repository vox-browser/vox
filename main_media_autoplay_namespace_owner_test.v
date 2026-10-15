module main

import browserjs
import dom
import html
import page
import time

const man_owner_first = 'urn:autoplay-owner-first'
const man_owner_second = 'urn:autoplay-owner-second'

fn man_owner_element(document &dom.Document, id string) !&dom.Element {
	return document.get_element_by_id(id) or { return error('Missing autoplay namespace element ${id}') }
}

fn man_owner_attr(element &dom.Element, namespace ?string) !&dom.Attr_ {
	return element.get_attribute_node_ns(namespace, 'autoplay') or { return error('Missing autoplay namespace attribute') }
}

fn man_owner_fixture() !(&BrowserApp, &dom.Document, &browserjs.Runtime) {
	mut owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><style>video{width:100px;height:40px}</style><main id="man-parent"><video id="man-video" preload="none"></video><audio id="man-audio" preload="none"></audio></main>', dom.URL{
		value: 'https://autoplay-namespace.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	for index, id in ['man-video', 'man-audio'] {
		mut element := man_owner_element(document, id)!
		if index == 1 { element.set_attribute_value('autoplay', 'initial null') }
		element.set_attribute_ns_for_bindings(man_owner_first, 'autoplay', 'first ${id}')!
		if index == 0 { element.set_attribute_value('autoplay', 'initial null') }
		element.set_attribute_ns_for_bindings(man_owner_second, 'autoplay', 'second ${id}')!
	}
	runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'globalThis.manParent=document.getElementById("man-parent");globalThis.manVideo=document.getElementById("man-video");globalThis.manAudio=document.getElementById("man-audio");void manVideo.paused;void manAudio.paused;0'], runtime, mut messages)
	assert messages == []
	app := &BrowserApp{ page_model: owner, document: document, js_runtime: runtime, viewport_width: 320, viewport_height: 240 }
	return app, document, runtime
}

fn man_owner_flush(document &dom.Document, runtime &browserjs.Runtime) ! {
	snapshot := runtime.evaluate_host('__ladybirdFinalize()')!
	mut messages := []string{}
	apply_javascript_state(document, snapshot, runtime.canvas_elements_for_binding(), mut messages)
	assert messages == []
	_ = runtime.evaluate_host('__ladybirdClearLogs();0')!
}

fn man_owner_balance(app &BrowserApp, document &dom.Document, runtime &browserjs.Runtime) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0 && runtime.libjs_vm().interpreter_stack().depth() == 0
	assert app.js_messages == []
}

fn test_native_autoplay_owner_preserves_foreign_duplicates_through_getter_query_and_dirty_replay() {
	$if !darwin { return }
	mut app, mut document, mut runtime := man_owner_fixture()!
	defer { runtime.close(); document.finalize() }
	for index, id in ['man-video', 'man-audio'] {
		element := man_owner_element(document, id)!
		name := if index == 0 { 'manVideo' } else { 'manAudio' }
		first := man_owner_attr(element, man_owner_first)!
		second := man_owner_attr(element, man_owner_second)!
		original_null := man_owner_attr(element, none)!
		mut media := html.html_media_element_for_dom_element(element) or { panic('Missing autoplay owner') }
		media.set_current_time(4)
		media.set_paused(false)
		assert runtime.evaluate_host('${name}.autoplay===true')! == 'true'
		assert runtime.evaluate_host('${name}.autoplay=false;${name}.setAttribute("data-dirty","first removal");document.querySelector("#${id}")===${name}&&!${name}.autoplay&&${name}.hasAttribute("autoplay")&&${name}.getAttribute("autoplay")==="first ${id}"')! == 'true'
		man_owner_flush(document, runtime)!
		assert !media.autoplay() && !element.has_attribute_ns(none, 'autoplay') && original_null.owner_element() == none
		assert voidptr(man_owner_attr(element, man_owner_first)!) == voidptr(first)
		assert voidptr(man_owner_attr(element, man_owner_second)!) == voidptr(second)
		assert first.value() == 'first ${id}' && second.value() == 'second ${id}'
		assert runtime.evaluate_host('${name}.autoplay=true;${name}.autoplay&&${name}.getAttribute("autoplay")==="first ${id}"')! == 'true'
		new_null := man_owner_attr(element, none)!
		assert media.autoplay() && new_null.value() == '' && voidptr(new_null) != voidptr(original_null)
		assert runtime.evaluate_host('${name}.autoplay=false;${name}.autoplay=false;${name}.setAttribute("data-dirty","repeated removal");!${name}.autoplay&&${name}.getAttribute("autoplay")==="first ${id}"')! == 'true'
		man_owner_flush(document, runtime)!
		assert !media.autoplay() && !element.has_attribute_ns(none, 'autoplay') && new_null.owner_element() == none
		assert element.get_attribute_names().filter(it == 'autoplay').len == 2
		assert voidptr(man_owner_attr(element, man_owner_first)!) == voidptr(first)
		assert voidptr(man_owner_attr(element, man_owner_second)!) == voidptr(second)
		assert first.value() == 'first ${id}' && second.value() == 'second ${id}'
		assert media.current_time() == 4 && !media.paused() && !media.muted() && media.volume() == 1
		assert media.current_src() == '' && media.network_state() == .empty && media.ready_state() == .have_nothing
		for event in ['seeking', 'seeked', 'timeupdate', 'ended', 'play', 'pause', 'volumechange', 'loadstart'] { assert media.event_count(event) == 0 }
	}
	app.relayout(320, 240 + app.chrome_height())
	man_owner_balance(app, document, runtime)
}


@[heap]
struct ManOwnerProbe {
mut:
	fetches int
	starts int
	getter_saw_reflection bool
}

fn man_owner_drain(document &dom.Document) {
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

fn test_native_autoplay_namespace_owner_defers_foreign_only_sources_and_preserves_reentrant_false() {
	$if !darwin { return }
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	app, mut document, mut runtime := man_owner_fixture()!
	defer { runtime.close(); document.finalize() }
	video_element := man_owner_element(document, 'man-video')!
	audio_element := man_owner_element(document, 'man-audio')!
	video_first := man_owner_attr(video_element, man_owner_first)!
	video_second := man_owner_attr(video_element, man_owner_second)!
	audio_first := man_owner_attr(audio_element, man_owner_first)!
	audio_second := man_owner_attr(audio_element, man_owner_second)!
	mut video := html.html_media_element_for_dom_element(video_element) or { panic('Missing autoplay video owner') }
	mut audio := html.html_media_element_for_dom_element(audio_element) or { panic('Missing autoplay audio owner') }
	video_probe := &ManOwnerProbe{}
	audio_probe := &ManOwnerProbe{}
	video.set_fetch_hook(fn [video_probe] (url dom.URL, offset u64) !html.MediaResourceResponse {
		mut observed := unsafe { &ManOwnerProbe(video_probe) }
		assert url.serialize() == 'https://autoplay-namespace.example.test/deferred-video.mp4' && offset == 0
		observed.fetches++
		return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 5, buffered_end: 5 }
	})
	runtime_handle := voidptr(runtime)
	audio.set_fetch_hook(fn [audio_probe, runtime_handle] (url dom.URL, offset u64) !html.MediaResourceResponse {
		mut observed := unsafe { &ManOwnerProbe(audio_probe) }
		mut current_runtime := unsafe { &browserjs.Runtime(runtime_handle) }
		assert url.serialize() == 'https://autoplay-namespace.example.test/deferred-audio.webm' && offset == 0
		observed.fetches++
		observed.getter_saw_reflection = current_runtime.evaluate_host('manAudio.autoplay&&manAudio.hasAttribute("autoplay")&&manAudio.getAttribute("autoplay")==="first man-audio"')! == 'true'
		assert observed.getter_saw_reflection
		assert current_runtime.evaluate_host('manAudio.autoplay=false;manAudio.setAttribute("data-reentrant","inner false");manAudio.paused&&!manAudio.autoplay&&manAudio.hasAttribute("autoplay")&&manAudio.getAttribute("autoplay")==="first man-audio"')! == 'true'
		return html.MediaResourceResponse{ mime_type: 'audio/webm', duration: 5, buffered_end: 5 }
	})
	for index, item in [video, audio] {
		probe := if index == 0 { video_probe } else { audio_probe }
		mut media := unsafe { &html.HTMLMediaElement(item) }
		media.set_playback_manager_hooks(html.MediaPlaybackManagerHooks{
			play: fn [probe] () {
				mut observed := unsafe { &ManOwnerProbe(probe) }
				observed.starts++
			}
		})
	}
	// An automatic src selection must remain deferred even under an allowing policy.
	assert runtime.evaluate_host('manVideo.autoplay=false;manAudio.autoplay=false;manVideo.src="/deferred-video.mp4";manAudio.src="/deferred-audio.webm";!manVideo.autoplay&&!manAudio.autoplay&&manVideo.hasAttribute("autoplay")&&manAudio.hasAttribute("autoplay")&&manVideo.paused&&manAudio.paused&&manVideo.readyState===0&&manAudio.readyState===0')! == 'true'
	assert video_probe.fetches == 0 && audio_probe.fetches == 0
	assert video.network_state() == .idle && audio.network_state() == .idle
	assert !video.autoplay() && !audio.autoplay()
	assert runtime.evaluate_host('manVideo.autoplay=true;manVideo.autoplay&&!manVideo.paused&&manVideo.readyState===4&&manVideo.getAttribute("autoplay")==="first man-video"')! == 'true'
	assert video_probe.fetches == 1 && video_probe.starts == 1 && video.autoplay()
	assert runtime.evaluate_host('manAudio.autoplay=true;!manAudio.autoplay&&manAudio.paused&&manAudio.readyState===4&&manAudio.hasAttribute("autoplay")&&manAudio.getAttribute("autoplay")==="first man-audio"&&manAudio.getAttribute("data-reentrant")==="inner false"')! == 'true'
	assert audio_probe.fetches == 1 && audio_probe.starts == 0 && audio_probe.getter_saw_reflection
	assert !audio.autoplay() && !audio_element.has_attribute_ns(none, 'autoplay')
	assert runtime.evaluate_host('manAudio.setAttribute("data-dirty","after outer return");document.querySelector("#man-audio")===manAudio&&!manAudio.autoplay&&manAudio.getAttribute("autoplay")==="first man-audio"')! == 'true'
	man_owner_flush(document, runtime)!
	assert voidptr(man_owner_attr(video_element, man_owner_first)!) == voidptr(video_first)
	assert voidptr(man_owner_attr(video_element, man_owner_second)!) == voidptr(video_second)
	assert voidptr(man_owner_attr(audio_element, man_owner_first)!) == voidptr(audio_first)
	assert voidptr(man_owner_attr(audio_element, man_owner_second)!) == voidptr(audio_second)
	assert video_first.value() == 'first man-video' && video_second.value() == 'second man-video'
	assert audio_first.value() == 'first man-audio' && audio_second.value() == 'second man-audio'
	assert !audio_element.has_attribute_ns(none, 'autoplay') && !audio.autoplay()
	man_owner_drain(document)
	assert video.event_count('play') == 1 && video.event_count('playing') == 1
	assert audio.event_count('play') == 0 && audio.event_count('playing') == 0
	assert video_probe.fetches == 1 && video_probe.starts == 1 && audio_probe.fetches == 1 && audio_probe.starts == 0
	man_owner_balance(app, document, runtime)
}
