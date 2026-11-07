module main

import browserjs
import dom
import html
import page
import time

const mpn_owner_first = 'urn:preload-owner-first'
const mpn_owner_second = 'urn:preload-owner-second'

fn mpn_owner_element(document &dom.Document, id string) !&dom.Element {
	return document.get_element_by_id(id) or { return error('Missing preload namespace element ${id}') }
}

fn mpn_owner_attr(element &dom.Element, namespace ?string) !&dom.Attr_ {
	return element.get_attribute_node_ns(namespace, 'preload') or { return error('Missing preload namespace attribute') }
}

fn mpn_owner_fixture() !(&BrowserApp, &dom.Document, &browserjs.Runtime) {
	mut owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><style>video{width:100px;height:40px}</style><main id="mpn-parent"><video id="mpn-video"></video><audio id="mpn-audio"></audio></main>', dom.URL{
		value: 'https://preload-namespace.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	for index, id in ['mpn-video', 'mpn-audio'] {
		mut element := mpn_owner_element(document, id)!
		if index == 1 { element.set_attribute_value('preload', 'NoNe') }
		element.set_attribute_ns_for_bindings(mpn_owner_first, 'preload', 'AuTo')!
		if index == 0 { element.set_attribute_value('preload', 'NoNe') }
		element.set_attribute_ns_for_bindings(mpn_owner_second, 'preload', 'none')!
	}
	runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'globalThis.mpnParent=document.getElementById("mpn-parent");globalThis.mpnVideo=document.getElementById("mpn-video");globalThis.mpnAudio=document.getElementById("mpn-audio");void mpnVideo.paused;void mpnAudio.paused;0'], runtime, mut messages)
	assert messages == []
	app := &BrowserApp{ page_model: owner, document: document, js_runtime: runtime, viewport_width: 320, viewport_height: 240 }
	return app, document, runtime
}

fn mpn_owner_flush(document &dom.Document, runtime &browserjs.Runtime) ! {
	snapshot := runtime.evaluate_host('__ladybirdFinalize()')!
	mut messages := []string{}
	apply_javascript_state(document, snapshot, runtime.canvas_elements_for_binding(), mut messages)
	assert messages == []
	_ = runtime.evaluate_host('__ladybirdClearLogs();0')!
}

fn mpn_owner_balance(app &BrowserApp, document &dom.Document, runtime &browserjs.Runtime) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0 && runtime.libjs_vm().interpreter_stack().depth() == 0
	assert app.js_messages == []
}


fn test_native_preload_owner_reads_null_raw_values_and_replays_qualified_removals_in_order() {
	$if !darwin { return }
	mut app, mut document, mut runtime := mpn_owner_fixture()!
	defer { runtime.close(); document.finalize() }
	for index, id in ['mpn-video', 'mpn-audio'] {
		element := mpn_owner_element(document, id)!
		name := if index == 0 { 'mpnVideo' } else { 'mpnAudio' }
		first := mpn_owner_attr(element, mpn_owner_first)!
		second := mpn_owner_attr(element, mpn_owner_second)!
		null_attr := mpn_owner_attr(element, none)!
		media := html.html_media_element_for_dom_element(element) or { panic('Missing preload owner') }
		assert runtime.evaluate_host('${name}.preload==="none"')! == 'true'
		assert null_attr.value() == 'NoNe' && first.value() == 'AuTo' && second.value() == 'none'
		for raw_index, raw in ['NONE', 'MeTaDaTa', 'AuTo', '', ' invalid '] {
			expected := ['none', 'metadata', 'auto', 'metadata', 'metadata'][raw_index]
			projection := if index == 0 { 'AuTo' } else { raw }
			assert runtime.evaluate_host('${name}.preload="${raw}";${name}.setAttribute("data-dirty","raw value");document.querySelector("#${id}")===${name}&&${name}.preload==="${expected}"&&${name}.getAttribute("preload")==="${projection}"')! == 'true'
			mpn_owner_flush(document, runtime)!
			assert media.preload() == expected && null_attr.value() == raw
			assert voidptr(mpn_owner_attr(element, none)!) == voidptr(null_attr)
			assert voidptr(mpn_owner_attr(element, mpn_owner_first)!) == voidptr(first)
			assert voidptr(mpn_owner_attr(element, mpn_owner_second)!) == voidptr(second)
			assert first.value() == 'AuTo' && second.value() == 'none'
		}
		expected_after_removal := if index == 0 { 'none' } else { 'metadata' }
		assert runtime.evaluate_host('${name}.preload="none";${name}.removeAttribute("preload");${name}.preload==="${expected_after_removal}"')! == 'true'
		if index == 0 {
			assert first.owner_element() == none
			assert voidptr(mpn_owner_attr(element, none)!) == voidptr(null_attr) && null_attr.value() == 'none'
		} else {
			assert null_attr.owner_element() == none && !element.has_attribute_ns(none, 'preload')
			assert voidptr(mpn_owner_attr(element, mpn_owner_first)!) == voidptr(first) && first.value() == 'AuTo'
		}
		assert runtime.evaluate_host('${name}.setAttribute("data-dirty","after qualified removal");document.querySelector("#${id}")===${name}&&${name}.preload==="${expected_after_removal}"')! == 'true'
		mpn_owner_flush(document, runtime)!
		assert media.preload() == expected_after_removal
		assert voidptr(mpn_owner_attr(element, mpn_owner_second)!) == voidptr(second) && second.value() == 'none'
		if index == 1 {
			assert !element.has_attribute_ns(none, 'preload')
			assert runtime.evaluate_host('${name}.preload="MeTaDaTa";${name}.preload==="metadata"&&${name}.getAttribute("preload")==="AuTo"')! == 'true'
			new_null := mpn_owner_attr(element, none)!
			assert voidptr(new_null) != voidptr(null_attr) && new_null.value() == 'MeTaDaTa'
			assert voidptr(mpn_owner_attr(element, mpn_owner_first)!) == voidptr(first)
		}
		assert media.paused() && media.current_time() == 0 && !media.muted() && media.volume() == 1
		assert media.current_src() == '' && media.network_state() == .empty && media.ready_state() == .have_nothing
		for event in ['play', 'playing', 'pause', 'volumechange', 'loadstart'] { assert media.event_count(event) == 0 }
	}
	app.relayout(320, 240 + app.chrome_height())
	mpn_owner_balance(app, document, runtime)
}

@[heap]
struct MpnOwnerProbe {
mut:
	fetches int
	starts int
	getter_saw_raw bool
}

fn mpn_owner_drain(document &dom.Document) {
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

fn test_native_preload_namespace_owner_preserves_inner_none_beside_foreign_auto_during_fetch() {
	$if !darwin { return }
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.block_audio_and_video, [])
	app, mut document, mut runtime := mpn_owner_fixture()!
	defer { runtime.close(); document.finalize() }
	video_element := mpn_owner_element(document, 'mpn-video')!
	audio_element := mpn_owner_element(document, 'mpn-audio')!
	video_first := mpn_owner_attr(video_element, mpn_owner_first)!
	video_second := mpn_owner_attr(video_element, mpn_owner_second)!
	audio_first := mpn_owner_attr(audio_element, mpn_owner_first)!
	audio_second := mpn_owner_attr(audio_element, mpn_owner_second)!
	mut video := html.html_media_element_for_dom_element(video_element) or { panic('Missing preload video owner') }
	mut audio := html.html_media_element_for_dom_element(audio_element) or { panic('Missing preload audio owner') }
	video_probe := &MpnOwnerProbe{}
	audio_probe := &MpnOwnerProbe{}
	runtime_handle := voidptr(runtime)
	video.set_fetch_hook(fn [video_probe, runtime_handle] (url dom.URL, offset u64) !html.MediaResourceResponse {
		mut observed := unsafe { &MpnOwnerProbe(video_probe) }
		mut current_runtime := unsafe { &browserjs.Runtime(runtime_handle) }
		assert url.serialize() == 'https://preload-namespace.example.test/deferred-video.mp4' && offset == 0
		observed.fetches++
		observed.getter_saw_raw = current_runtime.evaluate_host('mpnVideo.preload==="metadata"&&mpnVideo.getAttribute("preload")==="AuTo"')! == 'true'
		assert observed.getter_saw_raw
		assert current_runtime.evaluate_host('mpnVideo.preload="none";mpnVideo.setAttribute("data-reentrant","inner none");mpnVideo.paused&&mpnVideo.preload==="none"&&mpnVideo.getAttribute("preload")==="AuTo"')! == 'true'
		return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 5, buffered_end: 5 }
	})
	audio.set_fetch_hook(fn [audio_probe] (url dom.URL, offset u64) !html.MediaResourceResponse {
		mut observed := unsafe { &MpnOwnerProbe(audio_probe) }
		assert url.serialize() == 'https://preload-namespace.example.test/deferred-audio.webm' && offset == 0
		observed.fetches++
		return html.MediaResourceResponse{ mime_type: 'audio/webm', duration: 5, buffered_end: 5 }
	})
	for index, item in [video, audio] {
		probe := if index == 0 { video_probe } else { audio_probe }
		mut media := unsafe { &html.HTMLMediaElement(item) }
		media.set_playback_manager_hooks(html.MediaPlaybackManagerHooks{
			play: fn [probe] () {
				mut observed := unsafe { &MpnOwnerProbe(probe) }
				observed.starts++
			}
		})
	}
	assert runtime.evaluate_host('mpnVideo.src="/deferred-video.mp4";mpnAudio.src="/deferred-audio.webm";mpnVideo.preload==="none"&&mpnAudio.preload==="none"&&mpnVideo.paused&&mpnAudio.paused&&mpnVideo.readyState===0&&mpnAudio.readyState===0')! == 'true'
	assert video_probe.fetches == 0 && audio_probe.fetches == 0
	assert video.network_state() == .idle && audio.network_state() == .idle
	assert runtime.evaluate_host('mpnVideo.preload="MeTaDaTa";mpnVideo.preload==="none"&&mpnVideo.paused&&mpnVideo.readyState===4&&mpnVideo.getAttribute("preload")==="AuTo"&&mpnVideo.getAttribute("data-reentrant")==="inner none"')! == 'true'
	assert video_probe.fetches == 1 && video_probe.starts == 0 && video_probe.getter_saw_raw
	assert video_element.get_attribute_ns(none, 'preload')? == 'none' && video.preload() == 'none'
	assert runtime.evaluate_host('mpnAudio.preload="MeTaDaTa";mpnAudio.preload==="metadata"&&mpnAudio.paused&&mpnAudio.readyState===4&&mpnAudio.getAttribute("preload")==="MeTaDaTa"')! == 'true'
	assert audio_probe.fetches == 1 && audio_probe.starts == 0
	assert runtime.evaluate_host('mpnVideo.setAttribute("data-dirty","after outer return");document.querySelector("#mpn-video")===mpnVideo&&mpnVideo.preload==="none"&&mpnVideo.getAttribute("preload")==="AuTo"')! == 'true'
	mpn_owner_flush(document, runtime)!
	assert voidptr(mpn_owner_attr(video_element, mpn_owner_first)!) == voidptr(video_first)
	assert voidptr(mpn_owner_attr(video_element, mpn_owner_second)!) == voidptr(video_second)
	assert voidptr(mpn_owner_attr(audio_element, mpn_owner_first)!) == voidptr(audio_first)
	assert voidptr(mpn_owner_attr(audio_element, mpn_owner_second)!) == voidptr(audio_second)
	assert video_first.value() == 'AuTo' && audio_first.value() == 'AuTo'
	assert video_second.value() == 'none' && audio_second.value() == 'none'
	assert video_element.get_attribute_ns(none, 'preload')? == 'none' && video.preload() == 'none'
	mpn_owner_drain(document)
	for media in [video, audio] {
		assert media.paused() && media.current_time() == 0
		assert media.event_count('play') == 0 && media.event_count('playing') == 0
		assert media.event_count('loadstart') == 1 && media.event_count('loadeddata') == 1
	}
	assert video_probe.fetches == 1 && audio_probe.fetches == 1 && video_probe.starts == 0 && audio_probe.starts == 0
	mpn_owner_balance(app, document, runtime)
}
