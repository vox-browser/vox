module main

import browserjs
import dom
import html
import page
import time

const mdn_owner_first = 'urn:default-muted-first'
const mdn_owner_second = 'urn:default-muted-second'

@[heap]
struct MdnOwnerProbe {
mut:
	fetches int
	volume_updates []f64
}

fn mdn_owner_element(document &dom.Document, id string) !&dom.Element {
	return document.get_element_by_id(id) or { return error('Missing defaultMuted namespace element ${id}') }
}

fn mdn_owner_attribute(element &dom.Element, namespace ?string) !&dom.Attr_ {
	return element.get_attribute_node_ns(namespace, 'muted') or { return error('Missing defaultMuted namespace attribute') }
}

fn mdn_owner_fixture(with_null bool) !(&BrowserApp, &dom.Document, &browserjs.Runtime) {
	mut owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><style>video{width:100px;height:40px}</style><video id="mdn-video"></video><audio id="mdn-audio"></audio>', dom.URL{
		value: 'https://default-muted-namespace.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	for index, id in ['mdn-video', 'mdn-audio'] {
		mut element := mdn_owner_element(document, id)!
		if with_null && index == 1 { element.set_attribute_value('muted', 'initial null') }
		element.set_attribute_ns_for_bindings(mdn_owner_first, 'muted', 'first ${id}')!
		if with_null && index == 0 { element.set_attribute_value('muted', 'initial null') }
		element.set_attribute_ns_for_bindings(mdn_owner_second, 'muted', 'second ${id}')!
	}
	runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'globalThis.mdnVideo=document.getElementById("mdn-video");globalThis.mdnAudio=document.getElementById("mdn-audio");void mdnVideo.paused;void mdnAudio.paused;globalThis.mdnEvents=[];for(const target of [mdnVideo,mdnAudio])target.addEventListener("volumechange",event=>mdnEvents.push(event.target.id));0'], runtime, mut messages)
	assert messages == []
	app := &BrowserApp{ page_model: owner, document: document, js_runtime: runtime, viewport_width: 320, viewport_height: 240 }
	return app, document, runtime
}

fn mdn_owner_flush(document &dom.Document, runtime &browserjs.Runtime) ! {
	snapshot := runtime.evaluate_host('__ladybirdFinalize()')!
	mut messages := []string{}
	apply_javascript_state(document, snapshot, runtime.canvas_elements_for_binding(), mut messages)
	assert messages == []
	_ = runtime.evaluate_host('__ladybirdClearLogs();0')!
}

fn mdn_owner_take_task(document &dom.Document) ?&html.Task {
	mut queue := html.main_thread_event_loop().task_queue()
	return queue.take_first_runnable_matching(fn [document] (task &html.Task) bool {
		owner := task.document() or { return false }
		return task.source() == .media_element && voidptr(owner) == voidptr(document)
	})
}

fn mdn_owner_drain(document &dom.Document) {
	mut count := 0
	for {
		task := mdn_owner_take_task(document) or { break }
		count++
		assert count < 100
		task.execute()
	}
}

fn mdn_owner_balance(app &BrowserApp, document &dom.Document, runtime &browserjs.Runtime) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0 && runtime.libjs_vm().interpreter_stack().depth() == 0
	assert app.js_messages == []
}

fn test_native_default_muted_owner_removes_only_null_namespace_attribute_across_both_duplicate_orders() {
	$if !darwin { return }
	mut app, mut document, mut runtime := mdn_owner_fixture(true)!
	defer { runtime.close(); document.finalize() }
	for index, id in ['mdn-video', 'mdn-audio'] {
		element := mdn_owner_element(document, id)!
		name := if index == 0 { 'mdnVideo' } else { 'mdnAudio' }
		first := mdn_owner_attribute(element, mdn_owner_first)!
		second := mdn_owner_attribute(element, mdn_owner_second)!
		original_null := mdn_owner_attribute(element, none)!
		assert runtime.evaluate_host('${name}.defaultMuted===true&&${name}.muted===false')! == 'true'
		assert runtime.evaluate_host('${name}.defaultMuted=false;${name}.setAttribute("data-dirty","first absence");document.querySelector("#${id}")===${name}&&!${name}.defaultMuted&&${name}.hasAttribute("muted")&&${name}.getAttribute("muted")==="first ${id}"')! == 'true'
		mdn_owner_flush(document, runtime)!
		assert !element.has_attribute_ns(none, 'muted') && original_null.owner_element() == none
		assert voidptr(mdn_owner_attribute(element, mdn_owner_first)!) == voidptr(first)
		assert voidptr(mdn_owner_attribute(element, mdn_owner_second)!) == voidptr(second)
		assert first.value() == 'first ${id}' && second.value() == 'second ${id}'
		assert runtime.evaluate_host('${name}.defaultMuted=true;${name}.defaultMuted&&${name}.getAttribute("muted")==="first ${id}"')! == 'true'
		new_null := mdn_owner_attribute(element, none)!
		assert new_null.value() == '' && new_null.prefix() == none && voidptr(new_null) != voidptr(original_null)
		assert runtime.evaluate_host('${name}.defaultMuted=false;${name}.setAttribute("data-dirty","second absence");${name}.paused&&!${name}.defaultMuted&&${name}.getAttribute("muted")==="first ${id}"')! == 'true'
		mdn_owner_flush(document, runtime)!
		assert !element.has_attribute_ns(none, 'muted') && new_null.owner_element() == none
		assert element.get_attribute_names().filter(it == 'muted').len == 2
		assert voidptr(mdn_owner_attribute(element, mdn_owner_first)!) == voidptr(first)
		assert voidptr(mdn_owner_attribute(element, mdn_owner_second)!) == voidptr(second)
		assert first.value() == 'first ${id}' && second.value() == 'second ${id}'
		media := html.html_media_element_for_dom_element(element) or { panic('Missing defaultMuted media owner') }
		assert !media.muted() && media.volume() == 1 && media.paused() && media.current_time() == 0
		assert media.current_src() == '' && media.network_state() == .empty && media.ready_state() == .have_nothing
		for event in ['volumechange', 'loadstart', 'play', 'pause'] { assert media.event_count(event) == 0 }
	}
	assert runtime.evaluate_host('mdnEvents.length===0')! == 'true'
	assert mdn_owner_take_task(document) == none
	app.relayout(320, 240 + app.chrome_height())
	mdn_owner_balance(app, document, runtime)
}

fn test_native_default_muted_namespace_reflection_preserves_independent_runtime_mute_and_volume_events() {
	$if !darwin { return }
	mut app, mut document, mut runtime := mdn_owner_fixture(false)!
	defer { runtime.close(); document.finalize() }
	video_element := mdn_owner_element(document, 'mdn-video')!
	audio_element := mdn_owner_element(document, 'mdn-audio')!
	mut video := html.html_media_element_for_dom_element(video_element) or { panic('Missing namespace video') }
	audio := html.html_media_element_for_dom_element(audio_element) or { panic('Missing namespace audio') }
	probe := &MdnOwnerProbe{}
	for item in [video, audio] {
		mut media := unsafe { &html.HTMLMediaElement(item) }
		media.set_fetch_hook(fn [probe] (_ dom.URL, _ u64) !html.MediaResourceResponse {
			mut observed := unsafe { &MdnOwnerProbe(probe) }
			observed.fetches++
			return error('defaultMuted namespace reflection must not fetch')
		})
		media.set_playback_manager_hooks(html.MediaPlaybackManagerHooks{
			set_volume: fn [probe] (volume f64) {
				mut observed := unsafe { &MdnOwnerProbe(probe) }
				observed.volume_updates << volume
			}
		})
	}
	assert runtime.evaluate_host('!mdnVideo.defaultMuted&&!mdnAudio.defaultMuted&&mdnVideo.hasAttribute("muted")&&mdnAudio.hasAttribute("muted")')! == 'true'
	video.set_muted(true)
	mdn_owner_drain(document)
	assert runtime.evaluate_host('mdnVideo.muted&&!mdnAudio.muted&&!mdnVideo.defaultMuted&&!mdnAudio.defaultMuted&&mdnEvents.join(",")==="mdn-video"')! == 'true'
	assert probe.volume_updates == [0.0] && video.event_count('volumechange') == 1
	for index, element in [video_element, audio_element] {
		name := if index == 0 { 'mdnVideo' } else { 'mdnAudio' }
		id := if index == 0 { 'mdn-video' } else { 'mdn-audio' }
		first := mdn_owner_attribute(element, mdn_owner_first)!
		second := mdn_owner_attribute(element, mdn_owner_second)!
		assert runtime.evaluate_host('${name}.defaultMuted=true;${name}.defaultMuted=false;${name}.setAttribute("data-dirty","runtime unchanged");document.querySelector("#${id}")===${name}&&!${name}.defaultMuted&&${name}.getAttribute("muted")==="first ${id}"')! == 'true'
		mdn_owner_flush(document, runtime)!
		assert !element.has_attribute_ns(none, 'muted')
		assert voidptr(mdn_owner_attribute(element, mdn_owner_first)!) == voidptr(first)
		assert voidptr(mdn_owner_attribute(element, mdn_owner_second)!) == voidptr(second)
		assert first.value() == 'first ${id}' && second.value() == 'second ${id}'
	}
	assert video.muted() && !audio.muted() && probe.volume_updates == [0.0]
	assert video.event_count('volumechange') == 1 && audio.event_count('volumechange') == 0
	assert runtime.evaluate_host('mdnVideo.muted=false;!mdnVideo.muted&&!mdnVideo.defaultMuted&&mdnVideo.hasAttribute("muted")')! == 'true'
	mdn_owner_drain(document)
	assert probe.volume_updates == [0.0, 1.0] && video.event_count('volumechange') == 2
	assert runtime.evaluate_host('mdnEvents.join(",")==="mdn-video,mdn-video"')! == 'true'
	for media in [video, audio] {
		assert !media.muted() && media.volume() == 1 && media.paused() && media.current_time() == 0
		assert media.current_src() == '' && media.network_state() == .empty && media.ready_state() == .have_nothing
		for event in ['loadstart', 'play', 'pause'] { assert media.event_count(event) == 0 }
	}
	assert probe.fetches == 0 && mdn_owner_take_task(document) == none
	mdn_owner_balance(app, document, runtime)
}
