module main

import browserjs
import dom
import html
import page
import time

@[heap]
struct MtrrOwnerProbe {
mut:
	urls          []string
	cors          []html.CORSSettingAttribute
	media_fetches int
	states        []html.TextTrackReadinessState
	state_sources []string
	events        []&dom.Event
	event_sources []string
	old_cues      []&html.TextTrackCue
	redirected    bool
	resumed       bool
}

fn mtrr_owner_element(document &dom.Document, id string) !&dom.Element {
	return document.get_element_by_id(id) or { return error('Missing readiness reentry owner ${id}') }
}

fn mtrr_owner_fixture() !(&dom.Document, &browserjs.Runtime) {
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><video id="mtrr-parsed-video" preload="none" crossorigin="use-credentials"><track id="mtrr-parsed-video-track" src="seed-parsed-video.vtt"></video><audio id="mtrr-parsed-audio" preload="none" crossorigin="anonymous"><track id="mtrr-parsed-audio-track" src="seed-parsed-audio.vtt"></audio>', dom.URL{
		value: 'https://track-readiness.example.test/base/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	assert document.is_fully_active()
	runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
globalThis.mtrrTracks=[document.getElementById("mtrr-parsed-video-track"),document.getElementById("mtrr-parsed-audio-track")];
for(const kind of ["video","audio"]){
 const media=document.createElement(kind);media.id="mtrr-created-"+kind;
 media.setAttribute("preload","none");media.setAttribute("crossorigin",kind==="video"?"use-credentials":"anonymous");
 document.body.appendChild(media);
 const track=document.createElement("track");track.id="mtrr-created-"+kind+"-track";
 track.setAttribute("src","seed-created-"+kind+".vtt");media.appendChild(track);mtrrTracks.push(track);
}0'], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('mtrrTracks.length===4')! == 'true'
	return document, runtime
}

fn mtrr_owner_flush(document &dom.Document, runtime &browserjs.Runtime) ! {
	snapshot := runtime.evaluate_host('__ladybirdFinalize()')!
	mut messages := []string{}
	apply_javascript_runtime_state(document, snapshot, runtime, mut messages)
	assert messages == []
	_ = runtime.evaluate_host('__ladybirdClearLogs();0')!
}

fn mtrr_owner_observer(element &dom.Element, model &html.HTMLTrackElementModel, selected string, boundary html.TextTrackReadinessState, probe &MtrrOwnerProbe) &html.TextTrackObserver {
	mut track := model.track
	mut observer := html.TextTrackObserver.create(mut track)
	observer.set_track_readiness_observer(fn [element, model, selected, boundary, probe] (state html.TextTrackReadinessState) {
		mut observed := unsafe { &MtrrOwnerProbe(probe) }
		assert state == model.track.readiness_state()
		observed.states << state
		observed.state_sources << element.get_attribute_ns(none, 'src') or { panic('Missing observed source') }
		if state == boundary && !observed.redirected {
			observed.redirected = true
			if state == .loaded {
				observed.old_cues << model.track.cues().item(0) or { panic('Missing superseded terminal cue') }
			} else { assert model.track.cues().length() == 0 }
			// A real readiness observer changes the actual DOM source during notification.
			mut actual := unsafe { &dom.Element(element) }
			actual.set_attribute_value('src', selected)
			assert model.ready_state() == .loaded && model.track.cues().length() == 1
			assert observed.events.len == 1
			observed.resumed = true
		}
	})
	callback := &dom.CallbackType{
		handle_event: fn [element, model, selected, probe] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
			mut observed := unsafe { &MtrrOwnerProbe(probe) }
			assert event.type_name() == 'load' && !observed.resumed
			assert voidptr(event.target() or { panic('Missing readiness event target') }) == voidptr(element)
			assert voidptr(event.current_target() or { panic('Missing readiness current target') }) == voidptr(element)
			assert voidptr(current or { panic('Missing readiness callback owner') }) == voidptr(element)
			assert event.is_trusted() && !event.bubbles() && !event.cancelable()
			assert model.ready_state() == .loaded && model.track.cues().length() == 1
			assert (element.get_attribute_ns(none, 'src') or { panic('Missing readiness winning source') }) == selected
			observed.events << event
			observed.event_sources << selected
			return dom.js_undefined()
		}
	}
	for name in ['load', 'error'] {
		unsafe { &dom.EventTarget(element) }.add_event_listener_without_options(name, dom.IDLEventListener.create(callback))
	}
	return observer
}

fn mtrr_owner_balance(document &dom.Document, runtime &browserjs.Runtime) {
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

fn mtrr_owner_run(terminal bool) ! {
	mut document, mut runtime := mtrr_owner_fixture()!
	defer { runtime.close(); document.finalize() }
	for index, identity in ['parsed-video', 'parsed-audio', 'created-video', 'created-audio'] {
		probe := &MtrrOwnerProbe{}
		mut media := html.html_media_element_for_dom_element(mtrr_owner_element(document, 'mtrr-${identity}')!) or { return error('Missing readiness media owner') }
		media.set_fetch_hook(fn [probe] (_ dom.URL, _ u64) !html.MediaResourceResponse {
			mut observed := unsafe { &MtrrOwnerProbe(probe) }
			observed.media_fetches++
			return error('Track readiness reentry must not fetch media')
		})
		element := mtrr_owner_element(document, 'mtrr-${identity}-track')!
		track_dom := unsafe { &dom.HTMLTrackElement(element) }
		mut model := html.html_track_element_model_for_dom_element(track_dom)
		model.set_fetch_hook(fn [probe, index] (url dom.URL, cors html.CORSSettingAttribute) !html.TextTrackResourceResponse {
			mut observed := unsafe { &MtrrOwnerProbe(probe) }
			observed.urls << url.serialize()
			observed.cors << cors
			if index >= 2 && url.serialize().contains('/outer-') { return error('Controlled terminal readiness failure') }
			return html.TextTrackResourceResponse{ body: 'WEBVTT\n\n${url.serialize()}\n00:00.000 --> 00:01.000\n${url.serialize()}\n' }
		})
		// Only insertion is explicit; the compact source write starts observer reentry.
		html.html_track_element_inserted(track_dom)
		track := model.track
		list := track.cues()
		seed := list.item(0) or { panic('Missing seed before readiness notification') }
		selected := 'selected-${identity}.vtt'
		boundary := if !terminal { html.TextTrackReadinessState.loading } else if index < 2 { html.TextTrackReadinessState.loaded } else { html.TextTrackReadinessState.failed_to_load }
		mut observer := mtrr_owner_observer(element, model, selected, boundary, probe)
		outer := 'outer-${identity}.vtt'
		assert runtime.evaluate_host('mtrrTracks[${index}].setAttribute("src","${outer}");0')! == '0'
		mtrr_owner_flush(document, runtime)!
		observer.finalize()
		assert probe.redirected && probe.resumed && probe.events.len == 1
		assert probe.event_sources == [selected]
		assert probe.states == if terminal { [html.TextTrackReadinessState.loading, boundary, .loading, .loaded] } else { [html.TextTrackReadinessState.loading, .loading, .loaded] }
		assert probe.state_sources == if terminal { [outer, outer, selected, selected] } else { [outer, selected, selected] }
		assert model.ready_state() == .loaded && model.event_count('load') == 2 && model.event_count('error') == 0
		assert voidptr(html.html_track_element_model_for_dom_element(track_dom)) == voidptr(model)
		assert voidptr(model.event_target()) == voidptr(element) && voidptr(model.track) == voidptr(track)
		assert voidptr(track.cues()) == voidptr(list) && list.length() == 1
		cue := list.item(0) or { panic('Missing winning readiness cue') }
		assert cue.id() == 'https://track-readiness.example.test/base/${selected}' && cue.text() == cue.id()
		assert voidptr(cue.track() or { panic('Missing readiness cue owner') }) == voidptr(track)
		assert seed.track() == none && list.get_cue_by_id(seed.id()) == none
		assert list.get_cue_by_id('https://track-readiness.example.test/base/${outer}') == none
		assert probe.old_cues.len == if terminal && index < 2 { 1 } else { 0 }
		for old in probe.old_cues { assert old.track() == none }
		mut expected := ['https://track-readiness.example.test/base/seed-${identity}.vtt']
		if terminal { expected << 'https://track-readiness.example.test/base/${outer}' }
		expected << cue.id()
		assert probe.urls == expected && probe.cors.len == expected.len
		for cors in probe.cors { assert cors == if identity.ends_with('video') { html.CORSSettingAttribute.use_credentials } else { .anonymous } }
		assert probe.events[0].current_target() == none && probe.events[0].event_phase() == 0
		assert probe.media_fetches == 0 && media.paused() && media.current_time() == 0 && media.current_src() == ''
		assert media.network_state() == .empty && media.ready_state() == .have_nothing
		for name in ['loadstart', 'play', 'playing', 'pause', 'emptied', 'error'] { assert media.event_count(name) == 0 }
	}
	mtrr_owner_balance(document, runtime)
}

fn test_compact_track_loading_observer_replacement_suppresses_superseded_fetch() {
	$if !darwin { return }
	mtrr_owner_run(false)!
}

fn test_compact_track_terminal_observer_replacement_suppresses_superseded_load_and_error_events() {
	$if !darwin { return }
	mtrr_owner_run(true)!
}
