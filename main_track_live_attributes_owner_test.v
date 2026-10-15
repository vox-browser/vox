module main

import browserjs
import dom
import html
import page
import time

@[heap]
struct MtlaOwnerProbe {
mut:
	urls          []string
	cors          []html.CORSSettingAttribute
	media_fetches int
}

fn mtla_owner_element(document &dom.Document, id string) !&dom.Element {
	return document.get_element_by_id(id) or { return error('Missing live track owner ${id}') }
}

fn mtla_owner_fixture() !(&BrowserApp, &dom.Document, &browserjs.Runtime, &MtlaOwnerProbe) {
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><style>html,body{margin:0}video{display:block;width:90px;height:30px}</style><video id="mtla-video" preload="none" crossorigin="use-credentials"><track id="mtla-video-track" data-live-track="video" kind="captions" label="Original video" srclang="de" src="initial-video.vtt"></video><audio id="mtla-audio" preload="none" crossorigin="anonymous"><track id="mtla-audio-track" data-live-track="audio" kind="captions" label="Original audio" srclang="de" src="initial-audio.vtt"></audio><p id="mtla-result">waiting</p>', dom.URL{
		value: 'https://track-live.example.test/base/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	assert document.is_fully_active()
	probe := &MtlaOwnerProbe{}
	for kind in ['video', 'audio'] {
		parent := mtla_owner_element(document, 'mtla-${kind}')!
		mut media := html.html_media_element_for_dom_element(parent) or { return error('Missing live track parent') }
		media.set_fetch_hook(fn [probe] (_ dom.URL, _ u64) !html.MediaResourceResponse {
			mut observed := unsafe { &MtlaOwnerProbe(probe) }
			observed.media_fetches++
			return error('Live track mutations must not fetch the media resource')
		})
		element := mtla_owner_element(document, 'mtla-${kind}-track')!
		track_dom := unsafe { &dom.HTMLTrackElement(element) }
		mut model := html.html_track_element_model_for_dom_element(track_dom)
		assert model.ready_state() == .none && model.track.mode() == .disabled
		model.set_fetch_hook(fn [probe] (url dom.URL, cors html.CORSSettingAttribute) !html.TextTrackResourceResponse {
			mut observed := unsafe { &MtlaOwnerProbe(probe) }
			observed.urls << url.serialize()
			observed.cors << cors
			return html.TextTrackResourceResponse{
				body: 'WEBVTT\n\n${url.serialize()}\n00:00.000 --> 00:01.000\nlive owner cue\n'
			}
		})
		// Insertion remains explicit; later attribute mutations use the DOM hook.
		html.html_track_element_inserted(track_dom)
		assert model.track.mode() == .hidden && model.ready_state() == .loaded
		assert model.event_count('load') == 1 && model.event_count('error') == 0
	}
	assert probe.urls == ['https://track-live.example.test/base/initial-video.vtt', 'https://track-live.example.test/base/initial-audio.vtt']
	assert probe.cors == [html.CORSSettingAttribute.use_credentials, .anonymous]
	runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'globalThis.mtlaTracks=Array.from(document.querySelectorAll("track[data-live-track]"));globalThis.mtlaResult=document.getElementById("mtla-result");0'], runtime, mut messages)
	assert messages == []
	app := &BrowserApp{ page_model: owner, document: document, js_runtime: runtime, viewport_width: 320, viewport_height: 240 }
	return app, document, runtime, probe
}

fn mtla_owner_flush(document &dom.Document, runtime &browserjs.Runtime) ! {
	snapshot := runtime.evaluate_host('__ladybirdFinalize()')!
	mut messages := []string{}
	apply_javascript_runtime_state(document, snapshot, runtime, mut messages)
	assert messages == []
	_ = runtime.evaluate_host('__ladybirdClearLogs();0')!
}

fn mtla_owner_balance(app &BrowserApp, document &dom.Document, runtime &browserjs.Runtime, probe &MtlaOwnerProbe) {
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
		element := mtla_owner_element(document, 'mtla-${kind}') or { panic(err) }
		media := html.html_media_element_for_dom_element(element) or { panic('Missing retained live track parent') }
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

fn test_compact_track_metadata_mutations_update_existing_models_without_manual_attribute_hooks() {
	$if !darwin { return }
	mut app, mut document, mut runtime, probe := mtla_owner_fixture()!
	defer { runtime.close(); document.finalize() }
	for index, kind in ['video', 'audio'] {
		element := mtla_owner_element(document, 'mtla-${kind}-track')!
		track_dom := unsafe { &dom.HTMLTrackElement(element) }
		model := html.html_track_element_model_for_dom_element(track_dom)
		track := model.track
		alias := 'mtlaTracks[${index}]'
		assert runtime.evaluate_host('${alias}.setAttribute("kind","descriptions");${alias}.setAttribute("label","Live ${kind}");${alias}.setAttribute("srclang","fr");${alias}.setAttribute("id","mtla-renamed-${kind}");document.querySelector("#mtla-renamed-${kind}")===${alias}')! == 'true'
		mtla_owner_flush(document, runtime)!
		assert voidptr(html.html_track_element_model_for_dom_element(track_dom)) == voidptr(model)
		assert voidptr(model.track) == voidptr(track)
		assert model.track.kind() == .descriptions && model.track.label() == 'Live ${kind}'
		assert model.track.language() == 'fr' && model.track.id() == 'mtla-renamed-${kind}'
		assert element.get_attribute_ns(none, 'label')? == 'Live ${kind}'
		assert runtime.evaluate_host('${alias}.removeAttribute("kind");${alias}.removeAttribute("label");${alias}.removeAttribute("srclang");${alias}.removeAttribute("id");document.querySelectorAll("track[data-live-track]")[${index}]===${alias}')! == 'true'
		mtla_owner_flush(document, runtime)!
		assert voidptr(html.html_track_element_model_for_dom_element(track_dom)) == voidptr(model)
		assert voidptr(model.track) == voidptr(track)
		assert model.track.kind() == .subtitles && model.track.label() == ''
		assert model.track.language() == '' && model.track.id() == ''
		for name in ['kind', 'label', 'srclang', 'id'] { assert !element.has_attribute_ns(none, name) }
		assert model.ready_state() == .loaded && model.track.mode() == .hidden
		assert model.event_count('load') == 1 && model.event_count('error') == 0
	}
	assert runtime.evaluate_host('mtlaResult.textContent="live tracks updated";mtlaResult.style.color="rgb(51,62,73)";0')! == '0'
	mtla_owner_flush(document, runtime)!
	app.relayout(320, 240 + app.chrome_height())
	assert app.paint_commands.any(it.kind == 'draw_text' && it.text == 'live tracks updated' && it.color == 'rgb(51 62 73)')
	assert probe.urls.len == 2
	mtla_owner_balance(app, document, runtime, probe)
}

fn test_compact_track_source_mutations_fetch_once_per_changed_url_and_recover_after_empty_source() {
	$if !darwin { return }
	app, mut document, mut runtime, probe := mtla_owner_fixture()!
	defer { runtime.close(); document.finalize() }
	for index, kind in ['video', 'audio'] {
		element := mtla_owner_element(document, 'mtla-${kind}-track')!
		track_dom := unsafe { &dom.HTMLTrackElement(element) }
		model := html.html_track_element_model_for_dom_element(track_dom)
		track := model.track
		alias := 'mtlaTracks[${index}]'
		before := probe.urls.len
		assert runtime.evaluate_host('${alias}.setAttribute("src","changed-${kind}.vtt");document.querySelectorAll("track[data-live-track]")[${index}]===${alias}')! == 'true'
		mtla_owner_flush(document, runtime)!
		assert probe.urls.len == before + 1
		assert probe.urls.last() == 'https://track-live.example.test/base/changed-${kind}.vtt'
		assert probe.cors.last() == if index == 0 { html.CORSSettingAttribute.use_credentials } else { .anonymous }
		assert model.ready_state() == .loaded && model.event_count('load') == 2
		cue := model.track.cues().get_cue_by_id(probe.urls.last()) or { panic('Missing changed-source cue') }
		assert cue.text() == 'live owner cue'
		assert runtime.evaluate_host('${alias}.setAttribute("src","changed-${kind}.vtt");${alias}.setAttribute("data-repeat","same URL");0')! == '0'
		mtla_owner_flush(document, runtime)!
		assert probe.urls.len == before + 1 && model.event_count('load') == 2
		// Removing src keeps the selected URL, as in the existing concrete hook.
		assert runtime.evaluate_host('${alias}.removeAttribute("src");!${alias}.hasAttribute("src")')! == 'true'
		mtla_owner_flush(document, runtime)!
		assert !element.has_attribute_ns(none, 'src')
		assert probe.urls.len == before + 1 && model.event_count('load') == 2
		assert model.ready_state() == .loaded && model.event_count('error') == 0
		assert runtime.evaluate_host('${alias}.setAttribute("src","");${alias}.getAttribute("src")===""')! == 'true'
		mtla_owner_flush(document, runtime)!
		assert element.get_attribute_ns(none, 'src')? == ''
		assert probe.urls.len == before + 1 && model.event_count('load') == 2
		assert model.ready_state() == .error && model.event_count('error') == 1
		assert runtime.evaluate_host('${alias}.setAttribute("src","recovered-${kind}.vtt");document.querySelectorAll("track[data-live-track]")[${index}]===${alias}')! == 'true'
		mtla_owner_flush(document, runtime)!
		assert probe.urls.len == before + 2
		assert probe.urls.last() == 'https://track-live.example.test/base/recovered-${kind}.vtt'
		assert probe.cors.last() == if index == 0 { html.CORSSettingAttribute.use_credentials } else { .anonymous }
		assert model.ready_state() == .loaded && model.event_count('load') == 3 && model.event_count('error') == 1
		assert voidptr(html.html_track_element_model_for_dom_element(track_dom)) == voidptr(model)
		assert voidptr(model.track) == voidptr(track) && model.track.mode() == .hidden
		mtla_owner_flush(document, runtime)!
		assert probe.urls.len == before + 2 && model.event_count('load') == 3
	}
	assert probe.urls.len == 6
	mtla_owner_balance(app, document, runtime, probe)
}
