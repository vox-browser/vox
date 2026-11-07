module main

import browserjs
import dom
import html
import page
import time

@[heap]
struct MtsdeProbe {
mut:
	urls          []string
	cors          []html.CORSSettingAttribute
	media_fetches int
	parent_events []string
	events        []&dom.Event
	names         []string
	states        []html.TrackElementReadyState
	cue_counts    []int
}

fn mtsde_document(markup string, url string) !(&page.Page, &dom.Document) {
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{
		value: url
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	assert document.is_fully_active()
	return owner, document
}

fn mtsde_element(document &dom.Document, id string) !&dom.Element {
	return document.get_element_by_id(id) or { return error('Missing track DOM event owner ${id}') }
}

fn mtsde_parent(element &dom.Element, probe &MtsdeProbe) !&html.HTMLMediaElement {
	mut media := html.html_media_element_for_dom_element(element) or { return error('Missing track DOM event media owner') }
	media.set_fetch_hook(fn [probe] (_ dom.URL, _ u64) !html.MediaResourceResponse {
		mut observed := unsafe { &MtsdeProbe(probe) }
		observed.media_fetches++
		return error('Track DOM events must not fetch the media resource')
	})
	callback := &dom.CallbackType{
		handle_event: fn [probe] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut observed := unsafe { &MtsdeProbe(probe) }
			observed.parent_events << event.type_name()
			return dom.js_undefined()
		}
	}
	for name in ['load', 'error'] {
		unsafe { &dom.EventTarget(element) }.add_event_listener_without_options(name, dom.IDLEventListener.create(callback))
	}
	return media
}

fn mtsde_observe(element &dom.Element, probe &MtsdeProbe) {
	callback := &dom.CallbackType{
		handle_event: fn [element, probe] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
			mut observed := unsafe { &MtsdeProbe(probe) }
			target := unsafe { &dom.EventTarget(element) }
			assert voidptr(event.target() or { panic('Track DOM event needs a target') }) == voidptr(target)
			assert voidptr(event.current_target() or { panic('Track DOM event needs a current target') }) == voidptr(target)
			assert voidptr(current or { panic('Track DOM callback needs its owner') }) == voidptr(target)
			assert event.event_phase() == u16(dom.EventPhase.at_target)
			assert event.interface_ == .event && event.is_trusted()
			assert !event.bubbles() && !event.cancelable() && !event.composed()
			model := html.html_track_element_model_for_dom_element(unsafe { &dom.HTMLTrackElement(element) })
			assert voidptr(model.event_target()) == voidptr(target)
			assert model.event_count(event.type_name()) > 0
			observed.events << event
			observed.names << event.type_name()
			observed.states << model.ready_state()
			observed.cue_counts << model.track.cues().length()
			return dom.js_undefined()
		}
	}
	for name in ['load', 'error'] {
		unsafe { &dom.EventTarget(element) }.add_event_listener_without_options(name, dom.IDLEventListener.create(callback))
	}
}

fn mtsde_model(element &dom.Element, probe &MtsdeProbe) &html.HTMLTrackElementModel {
	// Register on the real DOM element before its lazy model exists.
	track_dom := unsafe { &dom.HTMLTrackElement(element) }
	assert track_dom.track_element_model_ == unsafe { nil }
	mtsde_observe(element, probe)
	mut model := html.html_track_element_model_for_dom_element(track_dom)
	assert voidptr(model.event_target()) == voidptr(element)
	model.set_fetch_hook(fn [probe] (url dom.URL, cors html.CORSSettingAttribute) !html.TextTrackResourceResponse {
		mut observed := unsafe { &MtsdeProbe(probe) }
		observed.urls << url.serialize()
		observed.cors << cors
		if url.serialize().contains('broken-') { return error('Controlled track DOM event fetch failure') }
		return html.TextTrackResourceResponse{
			body: 'WEBVTT\n\n${url.serialize()}\n00:00.000 --> 00:01.000\n${url.serialize()}\n'
		}
	})
	return model
}

fn mtsde_runtime(document &dom.Document) &browserjs.Runtime {
	runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'globalThis.mtsdeTracks=Array.from(document.querySelectorAll("track[data-dom-events]"));0'], runtime, mut messages)
	assert messages == []
	return runtime
}

fn mtsde_flush(document &dom.Document, runtime &browserjs.Runtime) ! {
	snapshot := runtime.evaluate_host('__ladybirdFinalize()')!
	mut messages := []string{}
	apply_javascript_runtime_state(document, snapshot, runtime, mut messages)
	assert messages == []
	_ = runtime.evaluate_host('__ladybirdClearLogs();0')!
}

fn mtsde_balance(document &dom.Document, runtime &browserjs.Runtime, probe &MtsdeProbe) {
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
	assert probe.media_fetches == 0 && probe.parent_events == []
	for event in probe.events {
		assert event.current_target() == none && event.event_phase() == 0
		assert event.target() != none && event.is_trusted() && !event.default_prevented()
	}
	for index, event in probe.events {
		for previous in probe.events[..index] { assert voidptr(event) != voidptr(previous) }
	}
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0 && runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn mtsde_unchanged_parent(media &html.HTMLMediaElement) {
	assert media.paused() && media.current_time() == 0 && media.current_src() == ''
	assert media.network_state() == .empty && media.ready_state() == .have_nothing
	for name in ['loadstart', 'play', 'playing', 'pause', 'emptied', 'error'] { assert media.event_count(name) == 0 }
}

fn test_compact_track_source_changes_deliver_load_and_error_to_actual_dom_listeners() {
	$if !darwin { return }
	_, mut document := mtsde_document('<!doctype html><video id="mtsde-video" preload="none" crossorigin="use-credentials"><track id="mtsde-video-track" data-dom-events="video" src="initial-video.vtt"></video><audio id="mtsde-audio" preload="none" crossorigin="anonymous"><track id="mtsde-audio-track" data-dom-events="audio" src="initial-audio.vtt"></audio>', 'https://track-dom-events.example.test/base/')!
	probe := &MtsdeProbe{}
	mut models := []&html.HTMLTrackElementModel{}
	for kind in ['video', 'audio'] {
		_ = mtsde_parent(mtsde_element(document, 'mtsde-${kind}')!, probe)!
		element := mtsde_element(document, 'mtsde-${kind}-track')!
		model := mtsde_model(element, probe)
		models << model
		html.html_track_element_inserted(unsafe { &dom.HTMLTrackElement(element) })
		assert model.ready_state() == .loaded && model.event_count('load') == 1
	}
	mut runtime := mtsde_runtime(document)
	defer { runtime.close(); document.finalize() }
	for index, kind in ['video', 'audio'] {
		element := mtsde_element(document, 'mtsde-${kind}-track')!
		model := models[index]
		list := model.track.cues()
		initial := list.item(0) or { panic('Missing initial track DOM event cue') }
		before := probe.events.len
		for stage, source in ['changed-${kind}.vtt', '', 'broken-${kind}.vtt', 'recovered-${kind}.vtt'] {
			assert runtime.evaluate_host('mtsdeTracks[${index}].setAttribute("src","${source}");document.querySelectorAll("track[data-dom-events]")[${index}]===mtsdeTracks[${index}]')! == 'true'
			mtsde_flush(document, runtime)!
			assert probe.events.len == before + stage + 1
			assert voidptr(probe.events.last().target() or { panic('Lost dispatched track owner') }) == voidptr(element)
			assert voidptr(model.track.cues()) == voidptr(list) && initial.track() == none
			if stage in [0, 3] {
				assert model.ready_state() == .loaded && list.length() == 1
				cue := list.item(0) or { panic('Missing loaded track DOM event cue') }
				assert cue.id() == 'https://track-dom-events.example.test/base/${source}'
				assert voidptr(cue.track() or { panic('Missing track DOM cue owner') }) == voidptr(model.track)
			} else { assert model.ready_state() == .error && list.length() == 0 }
		}
		assert probe.names[before..] == ['load', 'error', 'error', 'load']
		assert probe.states[before..] == [html.TrackElementReadyState.loaded, .error, .error, .loaded]
		assert probe.cue_counts[before..] == [1, 0, 0, 1]
		assert model.event_count('load') == 3 && model.event_count('error') == 2
		assert voidptr(html.html_track_element_model_for_dom_element(unsafe { &dom.HTMLTrackElement(element) })) == voidptr(model)
		mtsde_flush(document, runtime)!
		assert probe.events.len == before + 4
		media := html.html_media_element_for_dom_element(mtsde_element(document, 'mtsde-${kind}')!) or { panic('Missing retained track DOM parent') }
		mtsde_unchanged_parent(media)
	}
	assert probe.urls == ['https://track-dom-events.example.test/base/initial-video.vtt', 'https://track-dom-events.example.test/base/initial-audio.vtt', 'https://track-dom-events.example.test/base/changed-video.vtt', 'https://track-dom-events.example.test/base/broken-video.vtt', 'https://track-dom-events.example.test/base/recovered-video.vtt', 'https://track-dom-events.example.test/base/changed-audio.vtt', 'https://track-dom-events.example.test/base/broken-audio.vtt', 'https://track-dom-events.example.test/base/recovered-audio.vtt']
	assert probe.cors == [html.CORSSettingAttribute.use_credentials, .anonymous, .use_credentials, .use_credentials, .use_credentials, .anonymous, .anonymous, .anonymous]
	assert probe.names.len == 10 && probe.names[..2] == ['load', 'load']
	mtsde_balance(document, runtime, probe)
}

fn test_adopted_track_retains_dom_event_listeners_and_dispatches_after_compact_source_writes() {
	$if !darwin { return }
	_, mut original := mtsde_document('<!doctype html><body></body>', 'https://old-track-dom.example.test/old/')!
	defer { original.finalize() }
	_, mut destination := mtsde_document('<!doctype html><audio id="mtsde-destination" preload="none" crossorigin="anonymous"></audio>', 'https://new-track-dom.example.test/new/')!
	probe := &MtsdeProbe{}
	mut element := original.create_element('track')!
	element.set_attribute_value('id', 'mtsde-adopted')
	element.set_attribute_value('data-dom-events', 'adopted')
	element.set_attribute_value('src', 'before-adoption.vtt')
	model := mtsde_model(element, probe)
	track := model.track
	list := track.cues()
	assert model.ready_state() == .none && probe.events == []
	destination.adopt_node(element.as_node())
	element.set_attribute_value('src', 'after-adoption.vtt')
	parent := mtsde_element(destination, 'mtsde-destination')!
	media := mtsde_parent(parent, probe)!
	mut parent_node := parent.as_node()
	parent_node.append_child(element.as_node())!
	// Insertion remains explicit; adoption keeps the existing model and listener list.
	html.html_track_element_inserted(unsafe { &dom.HTMLTrackElement(element) })
	assert probe.urls == ['https://new-track-dom.example.test/new/after-adoption.vtt']
	assert probe.names == ['load'] && model.ready_state() == .loaded
	mut runtime := mtsde_runtime(destination)
	defer { runtime.close(); destination.finalize() }
	assert runtime.evaluate_host('mtsdeTracks.length===1&&mtsdeTracks[0].getAttribute("id")==="mtsde-adopted"')! == 'true'
	for source in ['broken-adopted.vtt', 'recovered-adopted.vtt'] {
		assert runtime.evaluate_host('mtsdeTracks[0].setAttribute("src","${source}");0')! == '0'
		mtsde_flush(destination, runtime)!
		assert voidptr(element.document()) == voidptr(destination)
		assert voidptr(html.html_track_element_model_for_dom_element(unsafe { &dom.HTMLTrackElement(element) })) == voidptr(model)
		assert voidptr(model.event_target()) == voidptr(element) && voidptr(model.track) == voidptr(track)
		assert voidptr(track.cues()) == voidptr(list)
		assert voidptr(probe.events.last().target() or { panic('Adoption lost track DOM target') }) == voidptr(element)
	}
	assert probe.names == ['load', 'error', 'load']
	assert probe.states == [html.TrackElementReadyState.loaded, .error, .loaded]
	assert probe.cue_counts == [1, 0, 1]
	assert probe.urls == ['https://new-track-dom.example.test/new/after-adoption.vtt', 'https://new-track-dom.example.test/new/broken-adopted.vtt', 'https://new-track-dom.example.test/new/recovered-adopted.vtt']
	assert probe.cors == [html.CORSSettingAttribute.anonymous, .anonymous, .anonymous]
	assert model.ready_state() == .loaded && model.event_count('load') == 2 && model.event_count('error') == 1
	assert list.length() == 1 && list.item(0)?.id() == probe.urls.last()
	mtsde_unchanged_parent(media)
	mtsde_balance(destination, runtime, probe)
}
