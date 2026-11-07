module main

import browserjs
import dom
import html
import page
import time

@[heap]
struct MtmeOwnerProbe {
mut:
	urls          []string
	cors          []html.CORSSettingAttribute
	media_fetches int
	events        []&dom.Event
	cue_counts    []int
	cleared       bool
	redirected    bool
}

fn mtme_owner_element(document &dom.Document, id string) !&dom.Element {
	return document.get_element_by_id(id) or { return error('Missing cue-end owner ${id}') }
}

fn mtme_owner_fixture() !(&dom.Document, &browserjs.Runtime) {
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><video id="mtme-parsed-video" preload="none" crossorigin="use-credentials"><track id="mtme-parsed-video-track" src="seed-parsed-video.vtt"></video><audio id="mtme-parsed-audio" preload="none" crossorigin="anonymous"><track id="mtme-parsed-audio-track" src="seed-parsed-audio.vtt"></audio>', dom.URL{
		value: 'https://track-missing-end.example.test/base/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	assert document.is_fully_active()
	runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
globalThis.mtmeTracks=[document.getElementById("mtme-parsed-video-track"),document.getElementById("mtme-parsed-audio-track")];
for(const kind of ["video","audio"]){
 const media=document.createElement(kind);media.id="mtme-created-"+kind;
 media.setAttribute("preload","none");media.setAttribute("crossorigin",kind==="video"?"use-credentials":"anonymous");
 document.body.appendChild(media);
 const track=document.createElement("track");track.id="mtme-created-"+kind+"-track";
 track.setAttribute("src","seed-created-"+kind+".vtt");media.appendChild(track);mtmeTracks.push(track);
}0'], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('mtmeTracks.length===4')! == 'true'
	return document, runtime
}

fn mtme_owner_flush(document &dom.Document, runtime &browserjs.Runtime) ! {
	snapshot := runtime.evaluate_host('__ladybirdFinalize()')!
	mut messages := []string{}
	apply_javascript_runtime_state(document, snapshot, runtime, mut messages)
	assert messages == []
	_ = runtime.evaluate_host('__ladybirdClearLogs();0')!
}

fn mtme_owner_vtt(url string, malformed bool, valid bool) string {
	missing := 'missing-end\n00:00.000 -->\nDiscard missing end\n'
	whitespace := 'whitespace-end\n00:01.000 -->  \t \nDiscard whitespace-only end\n'
	good := '${url}\n00:02.000 --> 00:03.000\n${url}\n'
	return 'WEBVTT\n\n' + if malformed {
		missing + '\n' + if valid { good + '\n' + whitespace } else { whitespace }
	} else { good }
}

fn mtme_owner_observe(element &dom.Element, model &html.HTMLTrackElementModel, recovery string, probe &MtmeOwnerProbe) {
	callback := &dom.CallbackType{
		handle_event: fn [element, model, recovery, probe] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
			mut observed := unsafe { &MtmeOwnerProbe(probe) }
			assert event.type_name() == 'load' && model.ready_state() == .loaded
			assert voidptr(event.target() or { panic('Missing cue-end event target') }) == voidptr(element)
			assert voidptr(event.current_target() or { panic('Missing cue-end current target') }) == voidptr(element)
			assert voidptr(current or { panic('Missing cue-end callback owner') }) == voidptr(element)
			assert event.is_trusted() && !event.bubbles() && !event.cancelable()
			observed.events << event
			observed.cue_counts << model.track.cues().length()
			if recovery != '' && !observed.redirected {
				assert observed.cleared && model.track.cues().length() == 0
				observed.redirected = true
				mut actual := unsafe { &dom.Element(element) }
				actual.set_attribute_value('src', recovery)
				assert observed.events.len == 2 && model.track.cues().length() == 1
			}
			return dom.js_undefined()
		}
	}
	for name in ['load', 'error'] {
		unsafe { &dom.EventTarget(element) }.add_event_listener_without_options(name, dom.IDLEventListener.create(callback))
	}
}

fn mtme_owner_balance(document &dom.Document, runtime &browserjs.Runtime) {
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

fn mtme_owner_run(pending_clear bool) ! {
	mut document, mut runtime := mtme_owner_fixture()!
	defer { runtime.close(); document.finalize() }
	for index, identity in ['parsed-video', 'parsed-audio', 'created-video', 'created-audio'] {
		probe := &MtmeOwnerProbe{}
		mut media := html.html_media_element_for_dom_element(mtme_owner_element(document, 'mtme-${identity}')!) or { return error('Missing cue-end media owner') }
		media.set_fetch_hook(fn [probe] (_ dom.URL, _ u64) !html.MediaResourceResponse {
			mut observed := unsafe { &MtmeOwnerProbe(probe) }
			observed.media_fetches++
			return error('Skipping malformed cue blocks must not fetch media')
		})
		element := mtme_owner_element(document, 'mtme-${identity}-track')!
		track_dom := unsafe { &dom.HTMLTrackElement(element) }
		mut model := html.html_track_element_model_for_dom_element(track_dom)
		pending := 'pending-clear-${identity}.vtt'
		model.set_fetch_hook(fn [probe, element, pending] (url dom.URL, cors html.CORSSettingAttribute) !html.TextTrackResourceResponse {
			mut observed := unsafe { &MtmeOwnerProbe(probe) }
			observed.urls << url.serialize()
			observed.cors << cors
			if url.serialize().ends_with('/${pending}') {
				assert !observed.cleared
				mut actual := unsafe { &dom.Element(element) }
				actual.set_attribute_value('src', './${pending}')
				observed.cleared = true
				return html.TextTrackResourceResponse{ body: mtme_owner_vtt(url.serialize(), true, true) }
			}
			malformed := url.serialize().contains('/malformed-') || url.serialize().contains('/mixed-')
			return html.TextTrackResourceResponse{ body: mtme_owner_vtt(url.serialize(), malformed, !url.serialize().contains('/malformed-')) }
		})
		// Initial insertion remains explicit; source changes use ordinary compact replay.
		html.html_track_element_inserted(track_dom)
		track := model.track
		list := track.cues()
		seed := list.item(0) or { panic('Missing cue-end seed') }
		recovery := 'recovery-${identity}.vtt'
		mtme_owner_observe(element, model, if pending_clear { recovery } else { '' }, probe)
		mut expected := ['https://track-missing-end.example.test/base/seed-${identity}.vtt']
		if pending_clear {
			assert runtime.evaluate_host('mtmeTracks[${index}].setAttribute("src","${pending}");0')! == '0'
			mtme_owner_flush(document, runtime)!
			expected << 'https://track-missing-end.example.test/base/${pending}'
			expected << 'https://track-missing-end.example.test/base/${recovery}'
			assert probe.cleared && probe.redirected && probe.cue_counts == [0, 1]
			assert (element.get_attribute_ns(none, 'src') or { panic('Missing recovered cue-end source') }) == recovery
			assert list.get_cue_by_id('https://track-missing-end.example.test/base/${pending}') == none
		} else {
			mut previous_cues := [seed]
			for stage, source in ['malformed-${identity}.vtt', 'mixed-${identity}.vtt', recovery] {
				assert runtime.evaluate_host('mtmeTracks[${index}].setAttribute("src","${source}");0')! == '0'
				mtme_owner_flush(document, runtime)!
				expected << 'https://track-missing-end.example.test/base/${source}'
				assert model.ready_state() == .loaded && list.length() == if stage == 0 { 0 } else { 1 }
				for previous in previous_cues { assert previous.track() == none }
				if stage > 0 {
					cue := list.item(0) or { panic('Missing valid cue beside malformed block') }
					assert cue.id() == expected.last()
					previous_cues << cue
				}
			}
			assert probe.cue_counts == [0, 1, 1] && !probe.cleared && !probe.redirected
		}
		assert probe.urls == expected && probe.cors.len == expected.len
		for cors in probe.cors { assert cors == if identity.ends_with('video') { html.CORSSettingAttribute.use_credentials } else { .anonymous } }
		assert model.event_count('load') == if pending_clear { 3 } else { 4 }
		assert model.event_count('error') == 0 && probe.events.len == expected.len - 1
		assert model.ready_state() == .loaded && list.length() == 1 && seed.track() == none
		assert voidptr(html.html_track_element_model_for_dom_element(track_dom)) == voidptr(model)
		assert voidptr(model.track) == voidptr(track) && voidptr(track.cues()) == voidptr(list)
		assert voidptr(model.event_target()) == voidptr(element)
		cue := list.item(0) or { panic('Missing final recovered cue-end cue') }
		assert cue.id() == expected.last() && voidptr(cue.track() or { panic('Missing cue-end cue owner') }) == voidptr(track)
		assert list.get_cue_by_id('missing-end') == none && list.get_cue_by_id('whitespace-end') == none
		for event in probe.events { assert event.current_target() == none && event.event_phase() == 0 }
		assert probe.media_fetches == 0 && media.paused() && media.current_time() == 0 && media.current_src() == ''
		assert media.network_state() == .empty && media.ready_state() == .have_nothing
		for name in ['loadstart', 'play', 'playing', 'pause', 'emptied', 'error'] { assert media.event_count(name) == 0 }
	}
	mtme_owner_balance(document, runtime)
}

fn test_compact_track_missing_end_blocks_load_empty_and_leave_valid_sibling_cues_usable() {
	$if !darwin { return }
	mtme_owner_run(false)!
}

fn test_compact_track_missing_end_blocks_preserve_pending_source_clear_and_listener_recovery() {
	$if !darwin { return }
	mtme_owner_run(true)!
}
