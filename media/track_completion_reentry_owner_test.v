module main

import browserjs
import dom
import html
import page
import time

@[heap]
struct MtcrOwnerProbe {
mut:
	urls          []string
	cors          []html.CORSSettingAttribute
	media_fetches int
	events        []&dom.Event
	names         []string
	steps         []string
	loaded_cues   []&html.TextTrackCue
	redirected    bool
}

fn mtcr_owner_element(document &dom.Document, id string) !&dom.Element {
	return document.get_element_by_id(id) or { return error('Missing completion reentry owner ${id}') }
}

fn mtcr_owner_fixture() !(&dom.Document, &browserjs.Runtime) {
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><video id="mtcr-parsed-video" preload="none" crossorigin="use-credentials"><track id="mtcr-parsed-video-track" src="seed-parsed-video.vtt"></video><audio id="mtcr-parsed-audio" preload="none" crossorigin="anonymous"><track id="mtcr-parsed-audio-track" src="seed-parsed-audio.vtt"></audio>', dom.URL{
		value: 'https://track-completion.example.test/base/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	assert document.is_fully_active()
	runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
globalThis.mtcrTracks=[document.getElementById("mtcr-parsed-video-track"),document.getElementById("mtcr-parsed-audio-track")];
for(const kind of ["video","audio"]){
 const media=document.createElement(kind);media.id="mtcr-created-"+kind;
 media.setAttribute("preload","none");media.setAttribute("crossorigin",kind==="video"?"use-credentials":"anonymous");
 document.body.appendChild(media);
 const track=document.createElement("track");track.id="mtcr-created-"+kind+"-track";
 track.setAttribute("src","seed-created-"+kind+".vtt");media.appendChild(track);mtcrTracks.push(track);
}0'], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('mtcrTracks.length===4')! == 'true'
	return document, runtime
}

fn mtcr_owner_flush(document &dom.Document, runtime &browserjs.Runtime) ! {
	snapshot := runtime.evaluate_host('__ladybirdFinalize()')!
	mut messages := []string{}
	apply_javascript_runtime_state(document, snapshot, runtime, mut messages)
	assert messages == []
	_ = runtime.evaluate_host('__ladybirdClearLogs();0')!
}

fn mtcr_owner_observe(element &dom.Element, model &html.HTMLTrackElementModel, next_source string, probe &MtcrOwnerProbe) {
	callback := &dom.CallbackType{
		handle_event: fn [element, model, next_source, probe] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
			mut observed := unsafe { &MtcrOwnerProbe(probe) }
			assert voidptr(event.target() or { panic('Missing reentrant track event target') }) == voidptr(element)
			assert voidptr(event.current_target() or { panic('Missing reentrant track current target') }) == voidptr(element)
			assert voidptr(current or { panic('Missing reentrant track callback owner') }) == voidptr(element)
			assert event.is_trusted() && !event.bubbles() && !event.cancelable()
			assert model.event_count(event.type_name()) > 0
			source := element.get_attribute_ns(none, 'src') or { panic('Missing reentrant source attribute') }
			observed.events << event
			observed.names << event.type_name()
			observed.steps << 'enter:${source}'
			if event.type_name() == 'load' {
				assert model.ready_state() == .loaded && model.track.cues().length() == 1
				observed.loaded_cues << model.track.cues().item(0) or { panic('Missing completion callback cue') }
			} else { assert event.type_name() == 'error' && model.ready_state() == .error && model.track.cues().length() == 0 }
			if !observed.redirected {
				observed.redirected = true
				// A native DOM listener changes the source during completion delivery.
				// The compact script starts the chain; no nested JS evaluation is needed.
				mut actual := unsafe { &dom.Element(element) }
				actual.set_attribute_value('src', next_source)
				assert model.ready_state() == .loaded && model.track.cues().length() == 1
				assert observed.events.len == 2
				observed.steps << 'resume:${next_source}'
			}
			observed.steps << 'exit:${source}'
			return dom.js_undefined()
		}
	}
	for name in ['load', 'error'] {
		unsafe { &dom.EventTarget(element) }.add_event_listener_without_options(name, dom.IDLEventListener.create(callback))
	}
}

fn mtcr_owner_balance(document &dom.Document, runtime &browserjs.Runtime) {
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
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0 && runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn mtcr_owner_run(failure bool) ! {
	mut document, mut runtime := mtcr_owner_fixture()!
	defer { runtime.close(); document.finalize() }
	for index, identity in ['parsed-video', 'parsed-audio', 'created-video', 'created-audio'] {
		probe := &MtcrOwnerProbe{}
		parent := mtcr_owner_element(document, 'mtcr-${identity}')!
		mut media := html.html_media_element_for_dom_element(parent) or { return error('Missing completion media owner') }
		media.set_fetch_hook(fn [probe] (_ dom.URL, _ u64) !html.MediaResourceResponse {
			mut observed := unsafe { &MtcrOwnerProbe(probe) }
			observed.media_fetches++
			return error('Track completion reentry must not fetch media')
		})
		element := mtcr_owner_element(document, 'mtcr-${identity}-track')!
		track_dom := unsafe { &dom.HTMLTrackElement(element) }
		mut model := html.html_track_element_model_for_dom_element(track_dom)
		model.set_fetch_hook(fn [probe] (url dom.URL, cors html.CORSSettingAttribute) !html.TextTrackResourceResponse {
			mut observed := unsafe { &MtcrOwnerProbe(probe) }
			observed.urls << url.serialize()
			observed.cors << cors
			if url.serialize().contains('broken-') { return error('Controlled completion reentry failure') }
			return html.TextTrackResourceResponse{ body: 'WEBVTT\n\n${url.serialize()}\n00:00.000 --> 00:01.000\n${url.serialize()}\n' }
		})
		// Seed before installing the listener; insertion is still an explicit hook.
		html.html_track_element_inserted(track_dom)
		track := model.track
		list := track.cues()
		seed := list.item(0) or { panic('Missing seed before completion reentry') }
		assert model.ready_state() == .loaded && model.event_count('load') == 1
		first := if failure { if index < 2 { '' } else { 'broken-${identity}.vtt' } } else { 'first-${identity}.vtt' }
		next := 'nested-${identity}.vtt'
		mtcr_owner_observe(element, model, next, probe)
		assert runtime.evaluate_host('mtcrTracks[${index}].setAttribute("src","${first}");0')! == '0'
		mtcr_owner_flush(document, runtime)!
		assert probe.names == [if failure { 'error' } else { 'load' }, 'load']
		assert probe.steps == ['enter:${first}', 'enter:${next}', 'exit:${next}', 'resume:${next}', 'exit:${first}']
		assert seed.track() == none && list.get_cue_by_id(seed.id()) == none
		assert voidptr(model.track) == voidptr(track) && voidptr(track.cues()) == voidptr(list)
		assert voidptr(html.html_track_element_model_for_dom_element(track_dom)) == voidptr(model)
		assert voidptr(model.event_target()) == voidptr(element)
		assert model.ready_state() == .loaded && list.length() == 1
		nested := list.item(0) or { panic('Missing nested completion cue') }
		assert nested.id() == 'https://track-completion.example.test/base/${next}'
		assert voidptr(nested.track() or { panic('Missing nested cue owner') }) == voidptr(track)
		assert (element.get_attribute_ns(none, 'src') or { panic('Missing final nested source') }) == next
		assert model.event_count('load') == if failure { 2 } else { 3 }
		assert model.event_count('error') == if failure { 1 } else { 0 }
		if !failure {
			assert probe.loaded_cues.len == 2 && probe.loaded_cues[0].track() == none
			assert voidptr(probe.loaded_cues[1]) == voidptr(nested)
		} else { assert probe.loaded_cues.len == 1 && voidptr(probe.loaded_cues[0]) == voidptr(nested) }
		mut expected := ['https://track-completion.example.test/base/seed-${identity}.vtt']
		if first != '' { expected << 'https://track-completion.example.test/base/${first}' }
		expected << nested.id()
		assert probe.urls == expected
		expected_cors := if identity.ends_with('video') { html.CORSSettingAttribute.use_credentials } else { .anonymous }
		for cors in probe.cors { assert cors == expected_cors }
		assert probe.cors.len == expected.len && probe.media_fetches == 0
		for event in probe.events { assert event.current_target() == none && event.event_phase() == 0 }
		assert voidptr(probe.events[0]) != voidptr(probe.events[1])
		assert media.paused() && media.current_time() == 0 && media.current_src() == ''
		assert media.network_state() == .empty && media.ready_state() == .have_nothing
		for name in ['loadstart', 'play', 'playing', 'pause', 'emptied', 'error'] { assert media.event_count(name) == 0 }
	}
	mtcr_owner_balance(document, runtime)
}

fn test_compact_track_load_listener_replaces_source_and_keeps_nested_loaded_cues() {
	$if !darwin { return }
	mtcr_owner_run(false)!
}

fn test_compact_track_error_listener_recovers_empty_and_failed_sources_before_returning() {
	$if !darwin { return }
	mtcr_owner_run(true)!
}
