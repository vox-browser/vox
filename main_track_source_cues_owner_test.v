module main

import browserjs
import dom
import html
import page
import time

const mtsc_owner_foreign_namespace = 'urn:track-source-cues-owner'

@[heap]
struct MtscOwnerProbe {
mut:
	urls          []string
	cors          []html.CORSSettingAttribute
	media_fetches int
}

fn mtsc_owner_element(document &dom.Document, id string) !&dom.Element {
	return document.get_element_by_id(id) or { return error('Missing source-cue owner ${id}') }
}

fn mtsc_owner_fixture(foreign_first bool) !(&BrowserApp, &dom.Document, &browserjs.Runtime, &MtscOwnerProbe) {
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><video id="mtsc-video" preload="none" crossorigin="use-credentials"><track id="mtsc-video-track" data-source-cues="video" src="initial-video.vtt"></video><audio id="mtsc-audio" preload="none" crossorigin="anonymous"><track id="mtsc-audio-track" data-source-cues="audio" src="initial-audio.vtt"></audio>', dom.URL{
		value: 'https://track-cues.example.test/base/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	assert document.is_fully_active()
	probe := &MtscOwnerProbe{}
	for kind in ['video', 'audio'] {
		parent := mtsc_owner_element(document, 'mtsc-${kind}')!
		mut media := html.html_media_element_for_dom_element(parent) or { return error('Missing source-cue media owner') }
		media.set_fetch_hook(fn [probe] (_ dom.URL, _ u64) !html.MediaResourceResponse {
			mut observation := unsafe { &MtscOwnerProbe(probe) }
			observation.media_fetches++
			return error('Changing track cues must not fetch media')
		})
		mut element := mtsc_owner_element(document, 'mtsc-${kind}-track')!
		if foreign_first {
			source := element.get_attribute_ns(none, 'src') or { panic('Missing initial plain source') }
			element.remove_attribute_ns(none, 'src')
			element.set_attribute_ns_for_bindings(mtsc_owner_foreign_namespace, 'src', 'foreign-first-${kind}.vtt')!
			element.set_attribute_value('src', source)
		}
		track_dom := unsafe { &dom.HTMLTrackElement(element) }
		mut model := html.html_track_element_model_for_dom_element(track_dom)
		model.set_fetch_hook(fn [probe] (url dom.URL, cors html.CORSSettingAttribute) !html.TextTrackResourceResponse {
			mut observation := unsafe { &MtscOwnerProbe(probe) }
			observation.urls << url.serialize()
			observation.cors << cors
			if url.serialize().contains('broken-') {
				return error('Controlled source-cue fetch failure')
			}
			return html.TextTrackResourceResponse{
				body: 'WEBVTT\n\n${url.serialize()}\n00:00.000 --> 00:01.000\n${url.serialize()}\n'
			}
		})
		// Only initial insertion is explicit; subsequent writes enter through DOM hooks.
		html.html_track_element_inserted(track_dom)
		assert model.ready_state() == .loaded && model.track.mode() == .hidden
		assert model.track.cues().length() == 1
		if !foreign_first {
			element.set_attribute_ns_for_bindings(mtsc_owner_foreign_namespace, 'p:src', 'foreign-${kind}.vtt')!
		}
		assert model.track.cues().length() == 1 && model.event_count('load') == 1
	}
	assert probe.urls == ['https://track-cues.example.test/base/initial-video.vtt', 'https://track-cues.example.test/base/initial-audio.vtt']
	assert probe.cors == [html.CORSSettingAttribute.use_credentials, .anonymous]
	runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'globalThis.mtscTracks=Array.from(document.querySelectorAll("track[data-source-cues]"));0'], runtime, mut messages)
	assert messages == []
	app := &BrowserApp{ page_model: owner, document: document, js_runtime: runtime, viewport_width: 320, viewport_height: 240 }
	return app, document, runtime, probe
}

fn mtsc_owner_flush(document &dom.Document, runtime &browserjs.Runtime) ! {
	snapshot := runtime.evaluate_host('__ladybirdFinalize()')!
	mut messages := []string{}
	apply_javascript_runtime_state(document, snapshot, runtime, mut messages)
	assert messages == []
	_ = runtime.evaluate_host('__ladybirdClearLogs();0')!
}

fn mtsc_owner_assert_attached(cue &html.TextTrackCue, track &html.TextTrack) {
	assert voidptr(cue.track() or { panic('Missing source-cue track association') }) == voidptr(track)
}

fn mtsc_owner_balance(app &BrowserApp, document &dom.Document, runtime &browserjs.Runtime, probe &MtscOwnerProbe) {
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
	assert probe.media_fetches == 0
	for kind in ['video', 'audio'] {
		element := mtsc_owner_element(document, 'mtsc-${kind}') or { panic(err) }
		media := html.html_media_element_for_dom_element(element) or { panic('Missing retained source-cue media owner') }
		assert media.paused() && media.current_time() == 0 && media.current_src() == ''
		assert media.network_state() == .empty && media.ready_state() == .have_nothing
		for event in ['loadstart', 'play', 'playing', 'pause', 'emptied', 'error'] { assert media.event_count(event) == 0 }
	}
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0 && runtime.libjs_vm().interpreter_stack().depth() == 0
	assert app.js_messages == []
}

fn mtsc_owner_foreign_first_sources() ! {
	app, mut document, mut runtime, probe := mtsc_owner_fixture(true)!
	defer { runtime.close(); document.finalize() }
	for index, kind in ['video', 'audio'] {
		element := mtsc_owner_element(document, 'mtsc-${kind}-track')!
		track_dom := unsafe { &dom.HTMLTrackElement(element) }
		model := html.html_track_element_model_for_dom_element(track_dom)
		track := model.track
		list := track.cues()
		initial := list.item(0) or { panic('Missing foreign-first source cue') }
		plain := element.get_attribute_node_ns(none, 'src') or { panic('Missing retained plain source') }
		foreign := element.get_attribute_node_ns(mtsc_owner_foreign_namespace, 'src') or { panic('Missing first foreign source') }
		assert voidptr(element.get_attribute_node('src') or { panic('Missing qualified source') }) == voidptr(foreign)
		assert plain.value() == 'initial-${kind}.vtt'
		assert initial.id() == 'https://track-cues.example.test/base/initial-${kind}.vtt'
		mtsc_owner_assert_attached(initial, track)
		before := probe.urls.len
		alias := 'mtscTracks[${index}]'
		assert runtime.evaluate_host('${alias}.getAttribute("src")==="foreign-first-${kind}.vtt"')! == 'true'
		for _ in 0 .. 2 {
			assert runtime.evaluate_host('${alias}.setAttribute("src","rewritten-foreign-${kind}.vtt");${alias}.getAttribute("src")==="rewritten-foreign-${kind}.vtt"')! == 'true'
			mtsc_owner_flush(document, runtime)!
			assert foreign.value() == 'rewritten-foreign-${kind}.vtt' && plain.value() == 'initial-${kind}.vtt'
			assert voidptr(element.get_attribute_node_ns(none, 'src') or { panic('Lost plain source') }) == voidptr(plain)
			assert voidptr(element.get_attribute_node_ns(mtsc_owner_foreign_namespace, 'src') or { panic('Lost foreign source') }) == voidptr(foreign)
			assert voidptr(track.cues()) == voidptr(list) && list.length() == 1
			assert voidptr(list.item(0) or { panic('Foreign rewrite removed source cue') }) == voidptr(initial)
			mtsc_owner_assert_attached(initial, track)
			assert probe.urls.len == before && model.ready_state() == .loaded
			assert model.event_count('load') == 1 && model.event_count('error') == 0
		}
		assert runtime.evaluate_host('${alias}.removeAttribute("src");${alias}.getAttribute("src")==="initial-${kind}.vtt"')! == 'true'
		mtsc_owner_flush(document, runtime)!
		assert foreign.owner_element() == none && !element.has_attribute_ns(mtsc_owner_foreign_namespace, 'src')
		assert plain.value() == 'initial-${kind}.vtt'
		assert voidptr(element.get_attribute_node('src') or { panic('Lost remaining plain source') }) == voidptr(plain)
		assert voidptr(track.cues()) == voidptr(list) && list.length() == 1
		mtsc_owner_assert_attached(initial, track)
		assert probe.urls.len == before && model.ready_state() == .loaded
		assert model.event_count('load') == 1 && model.event_count('error') == 0
		assert runtime.evaluate_host('${alias}.setAttribute("src","after-foreign-${kind}.vtt");${alias}.getAttribute("src")==="after-foreign-${kind}.vtt"')! == 'true'
		mtsc_owner_flush(document, runtime)!
		assert initial.track() == none && list.get_cue_by_id(initial.id()) == none
		assert voidptr(track.cues()) == voidptr(list) && list.length() == 1
		replacement := list.item(0) or { panic('Missing cue after foreign source removal') }
		assert replacement.id() == 'https://track-cues.example.test/base/after-foreign-${kind}.vtt'
		mtsc_owner_assert_attached(replacement, track)
		assert plain.value() == 'after-foreign-${kind}.vtt' && probe.urls.len == before + 1
		assert probe.cors.last() == if index == 0 { html.CORSSettingAttribute.use_credentials } else { .anonymous }
		assert model.ready_state() == .loaded && model.event_count('load') == 2 && model.event_count('error') == 0
		assert voidptr(html.html_track_element_model_for_dom_element(track_dom)) == voidptr(model)
	}
	assert probe.urls.len == 4
	mtsc_owner_balance(app, document, runtime, probe)
}

fn test_compact_track_source_changes_clear_retained_cues_without_replacing_the_live_list() {
	$if !darwin { return }
	app, mut document, mut runtime, probe := mtsc_owner_fixture(false)!
	defer { runtime.close(); document.finalize() }
	for index, kind in ['video', 'audio'] {
		mut element := mtsc_owner_element(document, 'mtsc-${kind}-track')!
		track_dom := unsafe { &dom.HTMLTrackElement(element) }
		model := html.html_track_element_model_for_dom_element(track_dom)
		track := model.track
		list := track.cues()
		initial := list.item(0) or { panic('Missing initial source cue') }
		initial_id := initial.id()
		mtsc_owner_assert_attached(initial, track)
		before := probe.urls.len
		element.set_attribute_ns_for_bindings(mtsc_owner_foreign_namespace, 'p:src', 'mutated-foreign-${kind}.vtt')!
		assert list.length() == 1 && probe.urls.len == before
		mtsc_owner_assert_attached(initial, track)
		element.remove_attribute_ns(mtsc_owner_foreign_namespace, 'src')
		assert list.length() == 1 && probe.urls.len == before
		mtsc_owner_assert_attached(initial, track)
		alias := 'mtscTracks[${index}]'
		assert runtime.evaluate_host('${alias}.setAttribute("src","changed-${kind}.vtt");document.querySelectorAll("track[data-source-cues]")[${index}]===${alias}')! == 'true'
		mtsc_owner_flush(document, runtime)!
		assert voidptr(track.cues()) == voidptr(list) && list.length() == 1
		assert initial.track() == none && list.get_cue_by_id(initial_id) == none
		changed := list.item(0) or { panic('Missing replacement source cue') }
		assert changed.id() == 'https://track-cues.example.test/base/changed-${kind}.vtt'
		assert changed.text() == changed.id()
		mtsc_owner_assert_attached(changed, track)
		assert probe.urls.len == before + 1 && probe.urls.last() == changed.id()
		assert probe.cors.last() == if index == 0 { html.CORSSettingAttribute.use_credentials } else { .anonymous }
		assert model.ready_state() == .loaded && model.event_count('load') == 2
		assert runtime.evaluate_host('${alias}.setAttribute("data-source-note","retain cue");0')! == '0'
		mtsc_owner_flush(document, runtime)!
		assert list.length() == 1 && voidptr(list.item(0) or { panic('Unrelated mutation cleared source cue') }) == voidptr(changed)
		mtsc_owner_assert_attached(changed, track)
		assert probe.urls.len == before + 1 && model.event_count('load') == 2
		assert runtime.evaluate_host('${alias}.setAttribute("src","changed-${kind}.vtt");0')! == '0'
		mtsc_owner_flush(document, runtime)!
		assert voidptr(track.cues()) == voidptr(list) && list.length() == 0
		assert changed.track() == none && list.get_cue_by_id(changed.id()) == none
		assert probe.urls.len == before + 1 && model.event_count('load') == 2
		assert model.ready_state() == .loaded && model.event_count('error') == 0
		assert runtime.evaluate_host('${alias}.setAttribute("src","last-${kind}.vtt");0')! == '0'
		mtsc_owner_flush(document, runtime)!
		last := list.item(0) or { panic('Missing cue before source removal') }
		assert list.length() == 1 && last.id() == 'https://track-cues.example.test/base/last-${kind}.vtt'
		mtsc_owner_assert_attached(last, track)
		assert runtime.evaluate_host('${alias}.removeAttribute("src");!${alias}.hasAttribute("src")')! == 'true'
		mtsc_owner_flush(document, runtime)!
		assert !element.has_attribute_ns(none, 'src')
		assert voidptr(track.cues()) == voidptr(list) && list.length() == 0 && last.track() == none
		assert model.ready_state() == .loaded && model.event_count('load') == 3 && model.event_count('error') == 0
		assert probe.urls.len == before + 2
		// Reintroducing that selected URL after removal still does not start another fetch.
		assert runtime.evaluate_host('${alias}.setAttribute("src","last-${kind}.vtt");0')! == '0'
		mtsc_owner_flush(document, runtime)!
		assert probe.urls.len == before + 2 && list.length() == 0 && model.event_count('load') == 3
		assert voidptr(html.html_track_element_model_for_dom_element(track_dom)) == voidptr(model)
		assert voidptr(model.track) == voidptr(track) && track.mode() == .hidden
	}
	assert probe.urls.len == 6
	mtsc_owner_balance(app, document, runtime, probe)
	mtsc_owner_foreign_first_sources()!
}

fn test_compact_track_empty_and_failed_sources_detach_old_cues_before_recovery() {
	$if !darwin { return }
	app, mut document, mut runtime, probe := mtsc_owner_fixture(false)!
	defer { runtime.close(); document.finalize() }
	for index, kind in ['video', 'audio'] {
		element := mtsc_owner_element(document, 'mtsc-${kind}-track')!
		track_dom := unsafe { &dom.HTMLTrackElement(element) }
		model := html.html_track_element_model_for_dom_element(track_dom)
		track := model.track
		list := track.cues()
		initial := list.item(0) or { panic('Missing cue before empty source') }
		mtsc_owner_assert_attached(initial, track)
		before := probe.urls.len
		alias := 'mtscTracks[${index}]'
		assert runtime.evaluate_host('${alias}.setAttribute("src","");${alias}.getAttribute("src")===""')! == 'true'
		mtsc_owner_flush(document, runtime)!
		assert voidptr(track.cues()) == voidptr(list) && list.length() == 0 && initial.track() == none
		assert list.get_cue_by_id(initial.id()) == none && probe.urls.len == before
		assert model.ready_state() == .error && model.event_count('load') == 1 && model.event_count('error') == 1
		assert runtime.evaluate_host('${alias}.setAttribute("src","ready-${kind}.vtt");0')! == '0'
		mtsc_owner_flush(document, runtime)!
		ready := list.item(0) or { panic('Missing cue before failed fetch') }
		assert list.length() == 1 && ready.id() == 'https://track-cues.example.test/base/ready-${kind}.vtt'
		mtsc_owner_assert_attached(ready, track)
		assert model.ready_state() == .loaded && model.event_count('load') == 2
		assert runtime.evaluate_host('${alias}.setAttribute("src","broken-${kind}.vtt");0')! == '0'
		mtsc_owner_flush(document, runtime)!
		assert voidptr(track.cues()) == voidptr(list) && list.length() == 0 && ready.track() == none
		assert list.get_cue_by_id(ready.id()) == none
		assert probe.urls.len == before + 2 && probe.urls.last() == 'https://track-cues.example.test/base/broken-${kind}.vtt'
		assert model.ready_state() == .error && model.event_count('load') == 2 && model.event_count('error') == 2
		assert runtime.evaluate_host('${alias}.setAttribute("src","recovered-${kind}.vtt");0')! == '0'
		mtsc_owner_flush(document, runtime)!
		recovered := list.item(0) or { panic('Missing recovered source cue') }
		assert voidptr(track.cues()) == voidptr(list) && list.length() == 1
		assert recovered.id() == 'https://track-cues.example.test/base/recovered-${kind}.vtt'
		assert recovered.text() == recovered.id()
		mtsc_owner_assert_attached(recovered, track)
		assert probe.urls.len == before + 3 && probe.urls.last() == recovered.id()
		assert probe.cors.last() == if index == 0 { html.CORSSettingAttribute.use_credentials } else { .anonymous }
		assert model.ready_state() == .loaded && model.event_count('load') == 3 && model.event_count('error') == 2
		assert initial.track() == none && ready.track() == none
		assert voidptr(html.html_track_element_model_for_dom_element(track_dom)) == voidptr(model)
		assert voidptr(model.track) == voidptr(track) && track.mode() == .hidden
		mtsc_owner_flush(document, runtime)!
		assert list.length() == 1 && probe.urls.len == before + 3 && model.event_count('load') == 3
	}
	assert probe.urls.len == 8
	mtsc_owner_balance(app, document, runtime, probe)
}
