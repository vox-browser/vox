module main

import browserjs
import dom
import html
import page
import time

@[heap]
struct MtpcOwnerProbe {
mut:
	urls          []string
	cors          []html.CORSSettingAttribute
	media_fetches int
	events        []&dom.Event
	names         []string
	cleared       bool
}

fn mtpc_owner_element(document &dom.Document, id string) !&dom.Element {
	return document.get_element_by_id(id) or { return error('Missing pending cue owner ${id}') }
}

fn mtpc_owner_fixture() !(&dom.Document, &browserjs.Runtime) {
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><video id="mtpc-parsed-video" preload="none" crossorigin="use-credentials"><track id="mtpc-parsed-video-track" src="seed-parsed-video.vtt"></video><audio id="mtpc-parsed-audio" preload="none" crossorigin="anonymous"><track id="mtpc-parsed-audio-track" src="seed-parsed-audio.vtt"></audio>', dom.URL{
		value: 'https://track-pending-cues.example.test/base/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	assert document.is_fully_active()
	runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
globalThis.mtpcTracks=[document.getElementById("mtpc-parsed-video-track"),document.getElementById("mtpc-parsed-audio-track")];
for(const kind of ["video","audio"]){
 const media=document.createElement(kind);media.id="mtpc-created-"+kind;
 media.setAttribute("preload","none");media.setAttribute("crossorigin",kind==="video"?"use-credentials":"anonymous");
 document.body.appendChild(media);
 const track=document.createElement("track");track.id="mtpc-created-"+kind+"-track";
 track.setAttribute("src","seed-created-"+kind+".vtt");media.appendChild(track);mtpcTracks.push(track);
}0'], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('mtpcTracks.length===4')! == 'true'
	return document, runtime
}

fn mtpc_owner_flush(document &dom.Document, runtime &browserjs.Runtime) ! {
	snapshot := runtime.evaluate_host('__ladybirdFinalize()')!
	mut messages := []string{}
	apply_javascript_runtime_state(document, snapshot, runtime, mut messages)
	assert messages == []
	_ = runtime.evaluate_host('__ladybirdClearLogs();0')!
}

fn mtpc_owner_observe(element &dom.Element, model &html.HTMLTrackElementModel, manual &html.TextTrackCue, expected_name string, probe &MtpcOwnerProbe) {
	callback := &dom.CallbackType{
		handle_event: fn [element, model, manual, expected_name, probe] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
			mut observed := unsafe { &MtpcOwnerProbe(probe) }
			assert observed.cleared && event.type_name() == expected_name
			assert voidptr(event.target() or { panic('Missing pending cue event target') }) == voidptr(element)
			assert voidptr(event.current_target() or { panic('Missing pending cue current target') }) == voidptr(element)
			assert voidptr(current or { panic('Missing pending cue callback owner') }) == voidptr(element)
			assert event.is_trusted() && !event.bubbles() && !event.cancelable()
			assert model.ready_state() == if expected_name == 'load' { html.TrackElementReadyState.loaded } else { .error }
			assert model.track.cues().length() == 1
			assert voidptr(model.track.cues().item(0) or { panic('Missing manually retained callback cue') }) == voidptr(manual)
			observed.events << event
			observed.names << event.type_name()
			return dom.js_undefined()
		}
	}
	for name in ['load', 'error'] {
		unsafe { &dom.EventTarget(element) }.add_event_listener_without_options(name, dom.IDLEventListener.create(callback))
	}
}

fn mtpc_owner_balance(document &dom.Document, runtime &browserjs.Runtime) {
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

fn mtpc_owner_run(remove_source bool) ! {
	mut document, mut runtime := mtpc_owner_fixture()!
	defer { runtime.close(); document.finalize() }
	for index, identity in ['parsed-video', 'parsed-audio', 'created-video', 'created-audio'] {
		probe := &MtpcOwnerProbe{}
		mut media := html.html_media_element_for_dom_element(mtpc_owner_element(document, 'mtpc-${identity}')!) or { return error('Missing pending cue media owner') }
		media.set_fetch_hook(fn [probe] (_ dom.URL, _ u64) !html.MediaResourceResponse {
			mut observed := unsafe { &MtpcOwnerProbe(probe) }
			observed.media_fetches++
			return error('Pending text-track cues must not fetch media')
		})
		element := mtpc_owner_element(document, 'mtpc-${identity}-track')!
		track_dom := unsafe { &dom.HTMLTrackElement(element) }
		mut model := html.html_track_element_model_for_dom_element(track_dom)
		pending := 'pending-${identity}.vtt'
		rewritten := match index {
			1 { './${pending}' }
			2 { 'https://track-pending-cues.example.test/base/${pending}' }
			else { pending }
		}
		mut manual := html.TextTrackCue.create(4, 5, 'Manually retained ${identity}')!
		manual.set_id('manual-${identity}')
		model.set_fetch_hook(fn [probe, element, model, manual, rewritten, remove_source, index] (url dom.URL, cors html.CORSSettingAttribute) !html.TextTrackResourceResponse {
			mut observed := unsafe { &MtpcOwnerProbe(probe) }
			observed.urls << url.serialize()
			observed.cors << cors
			if url.serialize().contains('/pending-') {
				assert !observed.cleared && model.ready_state() == .loading
				mut actual := unsafe { &dom.Element(element) }
				// These actual DOM writes clear cues without selecting a different URL.
				if remove_source { actual.remove_attribute_ns(none, 'src') } else { actual.set_attribute_value('src', rewritten) }
				assert model.track.cues().length() == 0 && observed.urls.len == 2
				mut track := model.track
				mut retained := unsafe { &html.TextTrackCue(manual) }
				track.add_cue(mut retained)
				observed.cleared = true
				if remove_source {
					match index {
						1 { return error('Pending response network failure after removal') }
						2 { return html.TextTrackResourceResponse{ status: 503 } }
						3 { return html.TextTrackResourceResponse{ body: 'Malformed pending response after removal' } }
						else {}
					}
				}
			}
			return html.TextTrackResourceResponse{ body: 'WEBVTT\n\n${url.serialize()}\n00:00.000 --> 00:01.000\n${url.serialize()}\n' }
		})
		// Seed once through the explicit insertion hook before the compact mutation.
		html.html_track_element_inserted(track_dom)
		track := model.track
		list := track.cues()
		seed := list.item(0) or { panic('Missing seed before pending cue invalidation') }
		expected_name := if remove_source && index != 0 { 'error' } else { 'load' }
		mtpc_owner_observe(element, model, manual, expected_name, probe)
		assert runtime.evaluate_host('mtpcTracks[${index}].setAttribute("src","${pending}");0')! == '0'
		mtpc_owner_flush(document, runtime)!
		assert probe.cleared && probe.names == [expected_name] && probe.events.len == 1
		assert model.event_count('load') == if expected_name == 'load' { 2 } else { 1 }
		assert model.event_count('error') == if expected_name == 'error' { 1 } else { 0 }
		assert model.ready_state() == if expected_name == 'load' { html.TrackElementReadyState.loaded } else { .error }
		assert voidptr(html.html_track_element_model_for_dom_element(track_dom)) == voidptr(model)
		assert voidptr(model.event_target()) == voidptr(element) && voidptr(model.track) == voidptr(track)
		assert voidptr(track.cues()) == voidptr(list) && list.length() == 1
		assert voidptr(list.item(0) or { panic('Missing manually retained final cue') }) == voidptr(manual)
		assert voidptr(manual.track() or { panic('Lost manual cue owner') }) == voidptr(track)
		assert seed.track() == none && list.get_cue_by_id(seed.id()) == none
		assert list.get_cue_by_id('https://track-pending-cues.example.test/base/${pending}') == none
		if remove_source { assert !element.has_attribute_ns(none, 'src') } else { assert (element.get_attribute_ns(none, 'src') or { panic('Missing rewritten source') }) == rewritten }
		assert probe.urls == ['https://track-pending-cues.example.test/base/seed-${identity}.vtt', 'https://track-pending-cues.example.test/base/${pending}']
		expected_cors := if identity.ends_with('video') { html.CORSSettingAttribute.use_credentials } else { .anonymous }
		assert probe.cors == [expected_cors, expected_cors]
		assert probe.events[0].current_target() == none && probe.events[0].event_phase() == 0
		if remove_source {
			// Restoring the selected URL clears the manual cue without a second fetch.
			mut actual := unsafe { &dom.Element(element) }
			actual.set_attribute_value('src', pending)
			assert probe.urls.len == 2 && probe.names == [expected_name]
			assert list.length() == 0 && manual.track() == none
			assert model.ready_state() == if expected_name == 'load' { html.TrackElementReadyState.loaded } else { .error }
			assert (element.get_attribute_ns(none, 'src') or { panic('Missing restored selected source') }) == pending
		}
		assert probe.media_fetches == 0 && media.paused() && media.current_time() == 0 && media.current_src() == ''
		assert media.network_state() == .empty && media.ready_state() == .have_nothing
		for name in ['loadstart', 'play', 'playing', 'pause', 'emptied', 'error'] { assert media.event_count(name) == 0 }
	}
	mtpc_owner_balance(document, runtime)
}

fn test_compact_pending_track_same_url_rewrites_preserve_manual_cues_without_readding_response_cues() {
	$if !darwin { return }
	mtpc_owner_run(false)!
}

fn test_compact_pending_track_source_removal_preserves_manual_cues_and_normal_completion_events() {
	$if !darwin { return }
	mtpc_owner_run(true)!
}
