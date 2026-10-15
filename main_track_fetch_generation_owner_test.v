module main

import browserjs
import dom
import html
import page
import time

@[heap]
struct MtfgOwnerProbe {
mut:
	urls          []string
	cors          []html.CORSSettingAttribute
	media_fetches int
	events        []&dom.Event
	names         []string
	sources       []string
	redirected    bool
	recovered     bool
	outer_resumed bool
}

fn mtfg_owner_element(document &dom.Document, id string) !&dom.Element {
	return document.get_element_by_id(id) or { return error('Missing track generation owner ${id}') }
}

fn mtfg_owner_fixture() !(&dom.Document, &browserjs.Runtime) {
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><video id="mtfg-parsed-video" preload="none" crossorigin="use-credentials"><track id="mtfg-parsed-video-track" src="seed-parsed-video.vtt"></video><audio id="mtfg-parsed-audio" preload="none" crossorigin="anonymous"><track id="mtfg-parsed-audio-track" src="seed-parsed-audio.vtt"></audio>', dom.URL{
		value: 'https://track-generation.example.test/base/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	assert document.is_fully_active()
	runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
globalThis.mtfgTracks=[document.getElementById("mtfg-parsed-video-track"),document.getElementById("mtfg-parsed-audio-track")];
for(const kind of ["video","audio"]){
 const media=document.createElement(kind);media.id="mtfg-created-"+kind;
 media.setAttribute("preload","none");media.setAttribute("crossorigin",kind==="video"?"use-credentials":"anonymous");
 document.body.appendChild(media);
 const track=document.createElement("track");track.id="mtfg-created-"+kind+"-track";
 track.setAttribute("src","seed-created-"+kind+".vtt");media.appendChild(track);mtfgTracks.push(track);
}0'], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('mtfgTracks.length===4')! == 'true'
	return document, runtime
}

fn mtfg_owner_flush(document &dom.Document, runtime &browserjs.Runtime) ! {
	snapshot := runtime.evaluate_host('__ladybirdFinalize()')!
	mut messages := []string{}
	apply_javascript_runtime_state(document, snapshot, runtime, mut messages)
	assert messages == []
	_ = runtime.evaluate_host('__ladybirdClearLogs();0')!
}

fn mtfg_owner_observe(element &dom.Element, model &html.HTMLTrackElementModel, recovery string, probe &MtfgOwnerProbe) {
	callback := &dom.CallbackType{
		handle_event: fn [element, model, recovery, probe] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
			mut observed := unsafe { &MtfgOwnerProbe(probe) }
			assert voidptr(event.target() or { panic('Missing generation event target') }) == voidptr(element)
			assert voidptr(event.current_target() or { panic('Missing generation current target') }) == voidptr(element)
			assert voidptr(current or { panic('Missing generation callback owner') }) == voidptr(element)
			assert event.is_trusted() && !event.bubbles() && !event.cancelable()
			assert !observed.outer_resumed
			observed.events << event
			observed.names << event.type_name()
			observed.sources << element.get_attribute_ns(none, 'src') or { panic('Missing generation source') }
			if event.type_name() == 'load' {
				assert model.ready_state() == .loaded && model.track.cues().length() == 1
			} else {
				assert event.type_name() == 'error' && model.ready_state() == .error
				assert model.track.cues().length() == 0 && recovery != '' && !observed.recovered
				observed.recovered = true
				// The native DOM error listener can select C while B completes.
				mut actual := unsafe { &dom.Element(element) }
				actual.set_attribute_value('src', recovery)
				assert model.ready_state() == .loaded && model.track.cues().length() == 1
			}
			return dom.js_undefined()
		}
	}
	for name in ['load', 'error'] {
		unsafe { &dom.EventTarget(element) }.add_event_listener_without_options(name, dom.IDLEventListener.create(callback))
	}
}

fn mtfg_owner_balance(document &dom.Document, runtime &browserjs.Runtime) {
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

fn mtfg_owner_run(recover bool) ! {
	mut document, mut runtime := mtfg_owner_fixture()!
	defer { runtime.close(); document.finalize() }
	for index, identity in ['parsed-video', 'parsed-audio', 'created-video', 'created-audio'] {
		probe := &MtfgOwnerProbe{}
		mut media := html.html_media_element_for_dom_element(mtfg_owner_element(document, 'mtfg-${identity}')!) or { return error('Missing generation media owner') }
		media.set_fetch_hook(fn [probe] (_ dom.URL, _ u64) !html.MediaResourceResponse {
			mut observed := unsafe { &MtfgOwnerProbe(probe) }
			observed.media_fetches++
			return error('Track fetch generations must not fetch media')
		})
		element := mtfg_owner_element(document, 'mtfg-${identity}-track')!
		track_dom := unsafe { &dom.HTMLTrackElement(element) }
		mut model := html.html_track_element_model_for_dom_element(track_dom)
		selected := 'selected-${identity}.vtt'
		recovery := if recover { 'recovery-${identity}.vtt' } else { '' }
		model.set_fetch_hook(fn [probe, element, model, selected, recover, index] (url dom.URL, cors html.CORSSettingAttribute) !html.TextTrackResourceResponse {
			mut observed := unsafe { &MtfgOwnerProbe(probe) }
			observed.urls << url.serialize()
			observed.cors << cors
			if url.serialize().contains('/outer-') {
				assert !observed.redirected && model.ready_state() == .loading
				assert model.track.cues().length() == 0
				observed.redirected = true
				// A controlled fetch hook selects B before returning A's result.
				// Compact JavaScript starts A; this hook performs an actual DOM write.
				mut actual := unsafe { &dom.Element(element) }
				actual.set_attribute_value('src', selected)
				assert model.ready_state() == .loaded && model.track.cues().length() == 1
				assert observed.events.len == if recover { 2 } else { 1 }
				observed.outer_resumed = true
				match index {
					1 { return error('Stale outer network failure') }
					2 {
						return html.TextTrackResourceResponse{
							status: 503
							body: 'stale status failure'
						}
					}
					3 { return html.TextTrackResourceResponse{ body: 'stale malformed WebVTT' } }
					else {}
				}
			}
			if recover && url.serialize().ends_with('/${selected}') { return error('Selected B fails before listener recovery') }
			return html.TextTrackResourceResponse{ body: 'WEBVTT\n\n${url.serialize()}\n00:00.000 --> 00:01.000\n${url.serialize()}\n' }
		})
		// The initial insertion hook seeds a retained cue before generation changes.
		html.html_track_element_inserted(track_dom)
		track := model.track
		list := track.cues()
		seed := list.item(0) or { panic('Missing seed before stale completion') }
		mtfg_owner_observe(element, model, recovery, probe)
		outer := 'outer-${identity}.vtt'
		assert runtime.evaluate_host('mtfgTracks[${index}].setAttribute("src","${outer}");0')! == '0'
		mtfg_owner_flush(document, runtime)!
		winner := if recover { recovery } else { selected }
		assert probe.redirected && probe.outer_resumed && probe.recovered == recover
		assert probe.names == if recover { ['error', 'load'] } else { ['load'] }
		assert probe.sources == if recover { [selected, recovery] } else { [selected] }
		assert model.ready_state() == .loaded && model.event_count('load') == 2
		assert model.event_count('error') == if recover { 1 } else { 0 }
		assert (element.get_attribute_ns(none, 'src') or { panic('Missing winning source') }) == winner
		assert voidptr(html.html_track_element_model_for_dom_element(track_dom)) == voidptr(model)
		assert voidptr(model.event_target()) == voidptr(element) && voidptr(model.track) == voidptr(track)
		assert voidptr(track.cues()) == voidptr(list) && list.length() == 1
		cue := list.item(0) or { panic('Missing winning generation cue') }
		assert cue.id() == 'https://track-generation.example.test/base/${winner}' && cue.text() == cue.id()
		assert voidptr(cue.track() or { panic('Missing winning cue owner') }) == voidptr(track)
		assert seed.track() == none && list.get_cue_by_id(seed.id()) == none
		assert list.get_cue_by_id('https://track-generation.example.test/base/${outer}') == none
		mut expected := ['https://track-generation.example.test/base/seed-${identity}.vtt', 'https://track-generation.example.test/base/${outer}', 'https://track-generation.example.test/base/${selected}']
		if recover { expected << cue.id() }
		assert probe.urls == expected && probe.cors.len == expected.len
		for cors in probe.cors { assert cors == if identity.ends_with('video') { html.CORSSettingAttribute.use_credentials } else { .anonymous } }
		for event in probe.events { assert event.current_target() == none && event.event_phase() == 0 }
		if recover { assert voidptr(probe.events[0]) != voidptr(probe.events[1]) }
		assert probe.media_fetches == 0 && media.paused() && media.current_time() == 0 && media.current_src() == ''
		assert media.network_state() == .empty && media.ready_state() == .have_nothing
		for name in ['loadstart', 'play', 'playing', 'pause', 'emptied', 'error'] { assert media.event_count(name) == 0 }
	}
	mtfg_owner_balance(document, runtime)
}

fn test_compact_track_source_replacement_ignores_stale_outer_success_and_failure_results() {
	$if !darwin { return }
	mtfg_owner_run(false)!
}

fn test_compact_track_selected_failure_listener_recovery_survives_stale_outer_results() {
	$if !darwin { return }
	mtfg_owner_run(true)!
}
