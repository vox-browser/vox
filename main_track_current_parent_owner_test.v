module main

import browserjs
import dom
import html
import page
import time

@[heap]
struct MtcpOwnerProbe {
mut:
	urls          []string
	cors          []html.CORSSettingAttribute
	media_fetches int
	events        []&dom.Event
}

fn mtcp_owner_element(document &dom.Document, id string) !&dom.Element {
	return document.get_element_by_id(id) or { return error('Missing current track parent owner ${id}') }
}

fn mtcp_owner_document(markup string, url string) !&dom.Document {
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{
		value: url
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	assert document.is_fully_active()
	return document
}

fn mtcp_owner_bind(document &dom.Document, source string) &browserjs.Runtime {
	runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [source], runtime, mut messages)
	assert messages == []
	return runtime
}

fn mtcp_owner_fixture() !(&dom.Document, &browserjs.Runtime) {
	document := mtcp_owner_document('<!doctype html><video id="mtcp-parsed-video" preload="none" crossorigin="use-credentials"><track id="mtcp-parsed-video-track" src="seed-parsed-video.vtt"></video><audio id="mtcp-parsed-audio" preload="none" crossorigin="anonymous"><track id="mtcp-parsed-audio-track" src="seed-parsed-audio.vtt"></audio><div id="mtcp-non-media"></div>', 'https://track-parent.example.test/base/')!
	runtime := mtcp_owner_bind(document, r'
globalThis.mtcpTracks=[document.getElementById("mtcp-parsed-video-track"),document.getElementById("mtcp-parsed-audio-track")];
for(const kind of ["video","audio"]){
 const media=document.createElement(kind);media.id="mtcp-created-"+kind;
 media.setAttribute("preload","none");media.setAttribute("crossorigin",kind==="video"?"use-credentials":"anonymous");
 document.body.appendChild(media);
 const track=document.createElement("track");track.id="mtcp-created-"+kind+"-track";
 track.setAttribute("src","seed-created-"+kind+".vtt");media.appendChild(track);mtcpTracks.push(track);
}0')
	assert runtime.evaluate_host('mtcpTracks.length===4')! == 'true'
	return document, runtime
}

fn mtcp_owner_flush(document &dom.Document, runtime &browserjs.Runtime) ! {
	snapshot := runtime.evaluate_host('__ladybirdFinalize()')!
	mut messages := []string{}
	apply_javascript_runtime_state(document, snapshot, runtime, mut messages)
	assert messages == []
	_ = runtime.evaluate_host('__ladybirdClearLogs();0')!
}

fn mtcp_owner_media(element &dom.Element, probe &MtcpOwnerProbe) !&html.HTMLMediaElement {
	mut media := html.html_media_element_for_dom_element(element) or { return error('Missing current track media owner') }
	media.set_fetch_hook(fn [probe] (_ dom.URL, _ u64) !html.MediaResourceResponse {
		mut observed := unsafe { &MtcpOwnerProbe(probe) }
		observed.media_fetches++
		return error('Resolving current track parents must not fetch media')
	})
	return media
}

fn mtcp_owner_seed(element &dom.Element, probe &MtcpOwnerProbe, insertion bool) &html.HTMLTrackElementModel {
	track_dom := unsafe { &dom.HTMLTrackElement(element) }
	mut model := html.html_track_element_model_for_dom_element(track_dom)
	model.set_fetch_hook(fn [probe] (url dom.URL, cors html.CORSSettingAttribute) !html.TextTrackResourceResponse {
		mut observed := unsafe { &MtcpOwnerProbe(probe) }
		observed.urls << url.serialize()
		observed.cors << cors
		return html.TextTrackResourceResponse{ body: 'WEBVTT\n\n${url.serialize()}\n00:00.000 --> 00:01.000\n${url.serialize()}\n' }
	})
	if insertion {
		html.html_track_element_inserted(track_dom)
	} else {
		model.set_mode(.hidden)
		model.start_the_track_processing_model()
	}
	assert model.ready_state() == .loaded && model.track.cues().length() == 1
	callback := &dom.CallbackType{
		handle_event: fn [element, model, probe] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
			mut observed := unsafe { &MtcpOwnerProbe(probe) }
			assert event.type_name() == 'load' && model.ready_state() == .loaded
			assert voidptr(event.target() or { panic('Missing current parent event target') }) == voidptr(element)
			assert voidptr(event.current_target() or { panic('Missing current parent current target') }) == voidptr(element)
			assert voidptr(current or { panic('Missing current parent callback owner') }) == voidptr(element)
			assert event.is_trusted() && !event.bubbles() && !event.cancelable()
			assert model.track.cues().length() == 1
			observed.events << event
			return dom.js_undefined()
		}
	}
	for name in ['load', 'error'] {
		unsafe { &dom.EventTarget(element) }.add_event_listener_without_options(name, dom.IDLEventListener.create(callback))
	}
	return model
}

fn mtcp_owner_unchanged(media &html.HTMLMediaElement) {
	assert media.paused() && media.current_time() == 0 && media.current_src() == ''
	assert media.network_state() == .empty && media.ready_state() == .have_nothing
	for name in ['loadstart', 'play', 'playing', 'pause', 'emptied', 'error'] { assert media.event_count(name) == 0 }
}

fn mtcp_owner_balance(document &dom.Document, runtime &browserjs.Runtime) {
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

fn test_compact_track_moves_and_adoption_sample_the_current_parent_without_insertion_hooks() {
	$if !darwin { return }
	mut document, mut runtime := mtcp_owner_fixture()!
	defer { runtime.close(); document.finalize() }
	mut destination := mtcp_owner_document('<!doctype html><video id="mtcp-target-video" preload="none" crossorigin="use-credentials"></video><audio id="mtcp-target-audio" preload="none" crossorigin="anonymous"></audio>', 'https://adopted-track-parent.example.test/new/')!
	defer { destination.finalize() }
	identities := ['parsed-video', 'parsed-audio', 'created-video', 'created-audio']
	mut models := []&html.HTMLTrackElementModel{}
	mut probes := []&MtcpOwnerProbe{}
	mut lists := []&html.TextTrackCueList{}
	for index, identity in identities {
		probe := &MtcpOwnerProbe{}
		media := mtcp_owner_media(mtcp_owner_element(document, 'mtcp-${identity}')!, probe)!
		element := mtcp_owner_element(document, 'mtcp-${identity}-track')!
		model := mtcp_owner_seed(element, probe, true)
		list := model.track.cues()
		seed := list.item(0) or { panic('Missing cue before parent move') }
		opposite := if identity.ends_with('video') { 'audio' } else { 'video' }
		assert runtime.evaluate_host('document.getElementById("mtcp-parsed-${opposite}").moveBefore(mtcpTracks[${index}],null);0')! == '0'
		mtcp_owner_flush(document, runtime)!
		assert probe.urls.len == 1 && probe.events == []
		assert runtime.evaluate_host('mtcpTracks[${index}].setAttribute("src","moved-${identity}.vtt");0')! == '0'
		mtcp_owner_flush(document, runtime)!
		assert seed.track() == none && list.length() == 1
		assert probe.urls == ['https://track-parent.example.test/base/seed-${identity}.vtt', 'https://track-parent.example.test/base/moved-${identity}.vtt']
		initial_cors := if identity.ends_with('video') { html.CORSSettingAttribute.use_credentials } else { .anonymous }
		moved_cors := if opposite == 'video' { html.CORSSettingAttribute.use_credentials } else { .anonymous }
		assert probe.cors == [initial_cors, moved_cors]
		assert model.event_count('load') == 2 && model.event_count('error') == 0 && probe.events.len == 1
		target := mtcp_owner_element(destination, 'mtcp-target-${opposite}')!
		_ = mtcp_owner_media(target, probe)!
		destination.adopt_node(element.as_node())
		mut target_node := target.as_node()
		target_node.append_child(element.as_node())!
		assert voidptr(element.document()) == voidptr(destination)
		models << model
		probes << probe
		lists << list
		mtcp_owner_unchanged(media)
	}
	mut adopted_runtime := mtcp_owner_bind(destination, r'globalThis.mtcpTracks=["parsed-video","parsed-audio","created-video","created-audio"].map(id=>document.getElementById("mtcp-"+id+"-track"));0')
	defer { adopted_runtime.close() }
	for index, identity in identities {
		model := models[index]
		probe := probes[index]
		list := lists[index]
		old := list.item(0) or { panic('Missing cue before adopted source write') }
		element := mtcp_owner_element(destination, 'mtcp-${identity}-track')!
		assert adopted_runtime.evaluate_host('mtcpTracks[${index}].setAttribute("src","adopted-${identity}.vtt");0')! == '0'
		mtcp_owner_flush(destination, adopted_runtime)!
		assert voidptr(html.html_track_element_model_for_dom_element(unsafe { &dom.HTMLTrackElement(element) })) == voidptr(model)
		assert voidptr(model.event_target()) == voidptr(element) && voidptr(model.track.cues()) == voidptr(list)
		assert old.track() == none && list.length() == 1
		cue := list.item(0) or { panic('Missing cue after adopted source write') }
		assert cue.id() == 'https://adopted-track-parent.example.test/new/adopted-${identity}.vtt'
		assert voidptr(cue.track() or { panic('Lost adopted cue owner') }) == voidptr(model.track)
		assert probe.urls.len == 3 && probe.urls.last() == cue.id()
		assert probe.cors.last() == if identity.ends_with('video') { html.CORSSettingAttribute.anonymous } else { .use_credentials }
		assert model.ready_state() == .loaded && model.event_count('load') == 3 && model.event_count('error') == 0
		assert probe.events.len == 2 && probe.media_fetches == 0
		for event in probe.events { assert event.current_target() == none && event.event_phase() == 0 }
	}
	for kind in ['video', 'audio'] {
		mtcp_owner_unchanged(html.html_media_element_for_dom_element(mtcp_owner_element(destination, 'mtcp-target-${kind}')!) or { panic('Missing adopted parent') })
	}
	mtcp_owner_balance(document, runtime)
	mtcp_owner_balance(destination, adopted_runtime)
}

fn test_compact_track_detach_and_non_media_reparenting_use_live_start_gates_and_no_cors() {
	$if !darwin { return }
	mut document, mut runtime := mtcp_owner_fixture()!
	defer { runtime.close(); document.finalize() }
	for index, identity in ['parsed-video', 'parsed-audio', 'created-video', 'created-audio'] {
		probe := &MtcpOwnerProbe{}
		parent := mtcp_owner_element(document, 'mtcp-${identity}')!
		media := mtcp_owner_media(parent, probe)!
		element := mtcp_owner_element(document, 'mtcp-${identity}-track')!
		// No insertion hook or cached media parent: the actual parent permits the start.
		mut model := mtcp_owner_seed(element, probe, false)
		list := model.track.cues()
		seed := list.item(0) or { panic('Missing cue before detached gate') }
		mut node := element.as_node()
		node.remove(false)
		model.start_the_track_processing_model()
		assert probe.urls.len == 1 && probe.events == []
		non_media := mtcp_owner_element(document, 'mtcp-non-media')!
		mut non_media_node := non_media.as_node()
		non_media_node.append_child(node)!
		model.start_the_track_processing_model()
		assert probe.urls.len == 1 && probe.events == []
		assert runtime.evaluate_host('mtcpTracks[${index}].setAttribute("src","non-media-${identity}.vtt");0')! == '0'
		mtcp_owner_flush(document, runtime)!
		assert seed.track() == none && model.ready_state() == .loaded && probe.cors.last() == .no_cors
		mut parent_node := parent.as_node()
		parent_node.append_child(node)!
		mut track := model.track
		mut observer := html.TextTrackObserver.create(mut track)
		observer.set_track_readiness_observer(fn [element, non_media, index] (state html.TextTrackReadinessState) {
			if state != .loading { return }
			mut actual := element.as_node()
			if index < 2 { actual.remove(false) } else {
				mut target := non_media.as_node()
				target.append_child(actual) or { panic(err) }
			}
		})
		old := list.item(0) or { panic('Missing cue before loading parent change') }
		assert runtime.evaluate_host('mtcpTracks[${index}].setAttribute("src","loading-parent-${identity}.vtt");0')! == '0'
		mtcp_owner_flush(document, runtime)!
		observer.finalize()
		assert old.track() == none && list.length() == 1 && voidptr(track.cues()) == voidptr(list)
		assert voidptr(html.html_track_element_model_for_dom_element(unsafe { &dom.HTMLTrackElement(element) })) == voidptr(model)
		assert voidptr(model.event_target()) == voidptr(element)
		assert probe.urls == ['https://track-parent.example.test/base/seed-${identity}.vtt', 'https://track-parent.example.test/base/non-media-${identity}.vtt', 'https://track-parent.example.test/base/loading-parent-${identity}.vtt']
		cue := list.item(0) or { panic('Missing cue after loading parent change') }
		assert cue.id() == probe.urls.last() && voidptr(model.track) == voidptr(track)
		assert probe.cors == [if identity.ends_with('video') { html.CORSSettingAttribute.use_credentials } else { .anonymous }, .no_cors, .no_cors]
		assert model.ready_state() == .loaded && model.event_count('load') == 3 && model.event_count('error') == 0
		assert probe.events.len == 2 && probe.media_fetches == 0
		if index < 2 { assert node.parent() == none } else { assert voidptr(node.parent() or { panic('Missing non-media parent') }) == voidptr(non_media) }
		for event in probe.events { assert event.current_target() == none && event.event_phase() == 0 }
		mtcp_owner_unchanged(media)
	}
	mtcp_owner_balance(document, runtime)
}
