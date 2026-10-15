module main

import browserjs
import dom
import html
import page
import time

const mcon_first = 'urn:crossorigin-owner-first'
const mcon_second = 'urn:crossorigin-owner-second'
const mcon_prefixed = 'urn:crossorigin-owner-prefixed'

fn mcon_element(document &dom.Document, id string) !&dom.Element {
	return document.get_element_by_id(id) or { return error('Missing crossorigin namespace element ${id}') }
}

fn mcon_attribute(element &dom.Element, namespace ?string) !&dom.Attr_ {
	return element.get_attribute_node_ns(namespace, 'crossorigin') or { return error('Missing crossorigin namespace attribute') }
}

fn mcon_fixture() !(&BrowserApp, &dom.Document, &browserjs.Runtime) {
	mut owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><style>html,body{margin:0}video{display:block;width:100px;height:40px}#mcon-result{color:rgb(17,34,51)}</style><main><video id="mcon-video-first" preload="none"></video><video id="mcon-video-last" preload="none"></video><audio id="mcon-audio-first" preload="none"></audio><audio id="mcon-audio-last" preload="none"></audio><p id="mcon-result">waiting</p></main>', dom.URL{
		value: 'https://crossorigin-namespace.example.test/base/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	for index, id in ['mcon-video-first', 'mcon-video-last', 'mcon-audio-first', 'mcon-audio-last'] {
		mut element := mcon_element(document, id)!
		if index % 2 == 1 { element.set_attribute_value('crossorigin', 'ANONYMOUS') }
		element.set_attribute_ns_for_bindings(mcon_first, 'crossorigin', 'use-credentials')!
		if index % 2 == 0 { element.set_attribute_value('crossorigin', 'ANONYMOUS') }
		element.set_attribute_ns_for_bindings(mcon_second, 'crossorigin', 'foreign second raw')!
		element.set_attribute_ns_for_bindings(mcon_prefixed, 'p:crossorigin', 'prefixed raw')!
	}
	runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'globalThis.mconPlayers=["mcon-video-first","mcon-video-last","mcon-audio-first","mcon-audio-last"].map(id=>document.getElementById(id));globalThis.mconResult=document.getElementById("mcon-result");for(const player of mconPlayers)void player.paused;0'], runtime, mut messages)
	assert messages == []
	app := &BrowserApp{ page_model: owner, document: document, js_runtime: runtime, viewport_width: 320, viewport_height: 240 }
	return app, document, runtime
}

fn mcon_flush(document &dom.Document, runtime &browserjs.Runtime) ! {
	snapshot := runtime.evaluate_host('__ladybirdFinalize()')!
	mut messages := []string{}
	apply_javascript_runtime_state(document, snapshot, runtime, mut messages)
	assert messages == []
	_ = runtime.evaluate_host('__ladybirdClearLogs();0')!
}

fn mcon_foreign_intact(element &dom.Element, first &dom.Attr_, second &dom.Attr_, prefixed &dom.Attr_) ! {
	for index, attribute in [first, second, prefixed] {
		namespace := [mcon_first, mcon_second, mcon_prefixed][index]
		assert voidptr(mcon_attribute(element, namespace)!) == voidptr(attribute)
		assert voidptr(attribute.owner_element() or { return error('Missing foreign crossorigin owner') }) == voidptr(element)
		assert (attribute.namespace_uri() or { '' }) == namespace && attribute.local_name() == 'crossorigin'
	}
	assert first.name() == 'crossorigin' && second.name() == 'crossorigin'
	assert first.prefix() == none && second.prefix() == none
	assert first.value() == 'use-credentials' && second.value() == 'foreign second raw'
	assert prefixed.name() == 'p:crossorigin' && (prefixed.prefix() or { '' }) == 'p' && prefixed.value() == 'prefixed raw'
}

fn mcon_balance(app &BrowserApp, document &dom.Document, runtime &browserjs.Runtime) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0 && runtime.libjs_vm().interpreter_stack().depth() == 0
	assert app.js_messages == []
}

fn test_native_crossorigin_namespace_owner_keeps_nullable_removal_separate_from_qualified_public_removal() {
	$if !darwin { return }
	mut app, mut document, mut runtime := mcon_fixture()!
	defer { runtime.close(); document.finalize() }
	for index, id in ['mcon-video-first', 'mcon-video-last', 'mcon-audio-first', 'mcon-audio-last'] {
		element := mcon_element(document, id)!
		first := mcon_attribute(element, mcon_first)!
		second := mcon_attribute(element, mcon_second)!
		prefixed := mcon_attribute(element, mcon_prefixed)!
		initial_null := mcon_attribute(element, none)!
		media := html.html_media_element_for_dom_element(element) or { panic('Missing crossorigin namespace owner') }
		player := 'mconPlayers[${index}]'
		assert runtime.evaluate_host('${player}.crossOrigin==="anonymous"')! == 'true'
		assert initial_null.value() == 'ANONYMOUS' && media.crossorigin() == .anonymous
		assert runtime.evaluate_host('${player}.crossOrigin=null;${player}.setAttribute("data-dirty","nullable absent");document.querySelector("#${id}")===${player}&&${player}.crossOrigin===null&&${player}.hasAttribute("crossorigin")&&${player}.getAttribute("crossorigin")==="use-credentials"')! == 'true'
		mcon_flush(document, runtime)!
		assert initial_null.owner_element() == none && !element.has_attribute_ns(none, 'crossorigin')
		assert media.cross_origin() == none && media.crossorigin() == .no_cors
		mcon_foreign_intact(element, first, second, prefixed)!
		assert runtime.evaluate_host('${player}.crossOrigin="UsE-CrEdEnTiAlS";${player}.crossOrigin==="use-credentials"&&${player}.getAttribute("crossorigin")==="use-credentials"')! == 'true'
		new_null := mcon_attribute(element, none)!
		assert new_null.value() == 'UsE-CrEdEnTiAlS' && voidptr(new_null) != voidptr(initial_null)
		assert runtime.evaluate_host('${player}.crossOrigin=undefined;${player}.crossOrigin===null&&${player}.hasAttribute("crossorigin")')! == 'true'
		assert new_null.owner_element() == none && media.crossorigin() == .no_cors
		mcon_foreign_intact(element, first, second, prefixed)!
		// The public qualified-name operation intentionally removes the first foreign slot.
		assert runtime.evaluate_host('${player}.crossOrigin="use-credentials";${player}.removeAttribute("crossorigin");${player}.setAttribute("data-dirty","qualified removal");document.querySelector("#${id}")===${player}&&${player}.crossOrigin==="use-credentials"&&${player}.getAttribute("crossorigin")==="foreign second raw"')! == 'true'
		mcon_flush(document, runtime)!
		assert first.owner_element() == none && media.crossorigin() == .use_credentials
		retained_null := mcon_attribute(element, none)!
		assert retained_null.value() == 'use-credentials'
		assert voidptr(mcon_attribute(element, mcon_second)!) == voidptr(second)
		assert runtime.evaluate_host('${player}.crossOrigin=null;${player}.setAttribute("data-dirty","last nullable removal");document.querySelector("#${id}")===${player}&&${player}.crossOrigin===null&&${player}.getAttribute("crossorigin")==="foreign second raw"')! == 'true'
		mcon_flush(document, runtime)!
		assert retained_null.owner_element() == none && !element.has_attribute_ns(none, 'crossorigin')
		assert voidptr(mcon_attribute(element, mcon_second)!) == voidptr(second) && second.value() == 'foreign second raw'
		assert voidptr(mcon_attribute(element, mcon_prefixed)!) == voidptr(prefixed) && prefixed.value() == 'prefixed raw'
		assert media.crossorigin() == .no_cors && media.paused() && media.current_time() == 0
		assert media.current_src() == '' && media.network_state() == .empty && media.ready_state() == .have_nothing
		for event in ['loadstart', 'play', 'playing', 'pause', 'emptied'] { assert media.event_count(event) == 0 }
	}
	assert runtime.evaluate_host('mconResult.textContent="namespace cross origin painted";mconResult.style.color="rgb(71,72,73)";document.querySelector("#mcon-result")===mconResult')! == 'true'
	mcon_flush(document, runtime)!
	app.relayout(320, 240 + app.chrome_height())
	assert app.paint_commands.any(it.kind == 'draw_text' && it.text == 'namespace cross origin painted' && it.color == 'rgb(71 72 73)')
	mcon_balance(app, document, runtime)
}

@[heap]
struct MconProbe {
mut:
	media_fetches int
	track_modes []html.CORSSettingAttribute
	track_urls []string
	track_owners []dom.UniqueNodeID
}

fn mcon_consume_track(element &dom.Element, probe &MconProbe, expected html.CORSSettingAttribute, index int) ! {
	mut document := element.document()
	mut track_element := document.create_element_ns(dom.namespace_html_uri, 'track')!
	track_element.set_attribute_value('kind', 'subtitles')
	track_element.set_attribute_value('src', 'captions-${index}.vtt')
	track_dom := unsafe { &dom.HTMLTrackElement(track_element) }
	mut track := html.html_track_element_model_for_dom_element(track_dom)
	track.set_fetch_hook(fn [probe, element] (url dom.URL, cors html.CORSSettingAttribute) !html.TextTrackResourceResponse {
		mut observed := unsafe { &MconProbe(probe) }
		observed.track_modes << cors
		observed.track_urls << url.serialize()
		observed.track_owners << element.document().unique_id()
		return html.TextTrackResourceResponse{ body: 'WEBVTT\n\n00:00.000 --> 00:01.000\nnamespace owner CORS\n' }
	})
	mut parent := element.as_node()
	parent.append_child(track_element.as_node())!
	html.html_track_element_inserted(track_dom)
	assert track.ready_state() == .loaded && track.track.cues().length() == 1
	assert track.event_count('load') == 1 && track.event_count('error') == 0
	assert probe.track_modes.len == index + 1 && probe.track_modes[index] == expected
	assert probe.track_urls[index] == document.base_url().serialize() + 'captions-${index}.vtt'
	assert probe.track_owners[index] == document.unique_id()
	cue := track.track.cues().item(0) or { return error('Missing namespace CORS cue') }
	assert cue.text() == 'namespace owner CORS'
}

fn mcon_drain(document &dom.Document) {
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

fn test_native_crossorigin_namespace_owner_drives_real_track_cors_after_adoption_without_promoting_media() {
	$if !darwin { return }
	app, mut document, mut runtime := mcon_fixture()!
	address := dom.URL{ value: 'https://crossorigin-namespace-adopted.example.test/next/' }
	mut destination := html.parse_navigation_document('<!doctype html><body></body>', address, address.origin(), none)!
	defer { runtime.close(); document.finalize(); destination.finalize() }
	probe := &MconProbe{}
	for index, id in ['mcon-video-first', 'mcon-audio-last'] {
		mut element := mcon_element(document, id)!
		first := mcon_attribute(element, mcon_first)!
		second := mcon_attribute(element, mcon_second)!
		prefixed := mcon_attribute(element, mcon_prefixed)!
		mut media := html.html_media_element_for_dom_element(element) or { panic('Missing deferred CORS owner') }
		media.set_fetch_hook(fn [probe] (_ dom.URL, _ u64) !html.MediaResourceResponse {
			mut observed := unsafe { &MconProbe(probe) }; observed.media_fetches++
			return error('crossOrigin must not promote deferred preload none')
		})
		media.set_source('https://crossorigin-namespace.example.test/base/deferred-${index}.mp4')
		media.select_resource()!
		media.set_current_playback_position(2.5)
		media.set_official_playback_position(2.5)
		mcon_drain(document)
		assert probe.media_fetches == 0 && media.paused() && media.network_state() == .idle
		before_source := media.current_src()
		events := ['loadstart', 'progress', 'suspend', 'loadedmetadata', 'loadeddata', 'play', 'playing', 'pause', 'emptied', 'error']
		mut before_events := []int{}
		for name in events { before_events << media.event_count(name) }
		player := if index == 0 { 'mconPlayers[0]' } else { 'mconPlayers[3]' }
		operations := ['${player}.crossOrigin=null', '${player}.crossOrigin="USE-CREDENTIALS"',
			'${player}.crossOrigin="invalid"', '${player}.crossOrigin=undefined']
		expected := [html.CORSSettingAttribute.no_cors, .use_credentials, .anonymous, .no_cors]
		for operation_index, operation in operations {
			assert runtime.evaluate_host(operation + ';' + player + '.setAttribute("data-dirty","track CORS");document.querySelector("#' + id + '")===' + player + '&&' + player + '.paused')! == 'true'
			mcon_flush(document, runtime)!
			assert media.crossorigin() == expected[operation_index]
			mcon_consume_track(element, probe, expected[operation_index], probe.track_modes.len)!
			mcon_foreign_intact(element, first, second, prefixed)!
		}
		destination.adopt_node(element.as_node())
		assert voidptr(element.document()) == voidptr(destination)
		assert voidptr(html.html_media_element_for_dom_element(element) or { panic('Missing adopted CORS owner') }) == voidptr(media)
		assert runtime.evaluate_host('${player}.crossOrigin="ANONYMOUS";${player}.crossOrigin==="anonymous"')! == 'true'
		mcon_consume_track(element, probe, .anonymous, probe.track_modes.len)!
		assert runtime.evaluate_host('${player}.crossOrigin=null;${player}.crossOrigin===null&&${player}.getAttribute("crossorigin")==="use-credentials"')! == 'true'
		mcon_flush(document, runtime)!
		mcon_consume_track(element, probe, .no_cors, probe.track_modes.len)!
		mcon_foreign_intact(element, first, second, prefixed)!
		assert probe.media_fetches == 0 && media.current_src() == before_source && media.current_time() == 2.5
		assert media.paused() && media.network_state() == .idle && media.ready_state() == .have_nothing
		for event_index, name in events { assert media.event_count(name) == before_events[event_index] }
	}
	assert probe.track_modes.len == 12 && probe.media_fetches == 0
	mcon_balance(app, document, runtime)
}
