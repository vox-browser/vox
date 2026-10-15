module main

import browserjs
import dom
import html
import page
import time

const mtn_foreign = 'urn:track-owner-foreign'
const mtn_prefixed = 'urn:track-owner-prefixed'

@[heap]
struct MtnProbe {
mut:
	urls []string
	cors []html.CORSSettingAttribute
	media_fetches int
}

fn mtn_element(document &dom.Document, id string) !&dom.Element {
	return document.get_element_by_id(id) or { return error('Missing track namespace owner ${id}') }
}

fn mtn_attribute(element &dom.Element, namespace ?string, name string) !&dom.Attr_ {
	return element.get_attribute_node_ns(namespace, name) or { return error('Missing track namespace ${name}') }
}

fn mtn_document() !(&page.Page, &dom.Document) {
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><style>html,body{margin:0}video{display:block;width:90px;height:30px}</style><video id="mtn-video" preload="none"></video><audio id="mtn-audio" preload="none"></audio><p id="mtn-result">waiting</p>', dom.URL{
		value: 'https://track-namespace.example.test/base/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	assert document.is_fully_active()
	mut video := mtn_element(document, 'mtn-video')!
	video.set_attribute_ns_for_bindings(mtn_foreign, 'crossorigin', 'anonymous')!
	video.set_attribute_value('crossorigin', 'use-credentials')
	mut audio := mtn_element(document, 'mtn-audio')!
	audio.set_attribute_value('crossorigin', 'anonymous')
	audio.set_attribute_ns_for_bindings(mtn_foreign, 'crossorigin', 'use-credentials')!
	return owner, document
}

fn mtn_bind(owner &page.Page, document &dom.Document) !(&BrowserApp, &browserjs.Runtime) {
	runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'globalThis.mtnPlayers=[document.getElementById("mtn-video"),document.getElementById("mtn-audio")];globalThis.mtnTracks=Array.from(document.querySelectorAll("track[data-mtn-owner]"));globalThis.mtnResult=document.getElementById("mtn-result");for(const player of mtnPlayers)void player.paused;0'], runtime, mut messages)
	assert messages == []
	app := &BrowserApp{ page_model: owner, document: document, js_runtime: runtime, viewport_width: 320, viewport_height: 240 }
	return app, runtime
}

fn mtn_flush(document &dom.Document, runtime &browserjs.Runtime) ! {
	snapshot := runtime.evaluate_host('__ladybirdFinalize()')!
	mut messages := []string{}
	apply_javascript_runtime_state(document, snapshot, runtime, mut messages)
	assert messages == []
	_ = runtime.evaluate_host('__ladybirdClearLogs();0')!
}

fn mtn_media(document &dom.Document, index int, probe &MtnProbe) !&html.HTMLMediaElement {
	element := mtn_element(document, ['mtn-video', 'mtn-audio'][index])!
	mut media := html.html_media_element_for_dom_element(element) or { return error('Missing track parent model') }
	media.set_fetch_hook(fn [probe] (_ dom.URL, _ u64) !html.MediaResourceResponse {
		mut observed := unsafe { &MtnProbe(probe) }
		observed.media_fetches++
		return error('Text track processing must not fetch the media resource')
	})
	return media
}

fn mtn_drain(document &dom.Document) {
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

fn mtn_balance(app &BrowserApp, document &dom.Document, runtime &browserjs.Runtime) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0 && runtime.libjs_vm().interpreter_stack().depth() == 0
	assert app.js_messages == []
}

fn test_real_track_initialization_uses_null_slots_beside_foreign_qualified_projections() {
	$if !darwin { return }
	owner, mut document := mtn_document()!
	probe := &MtnProbe{}
	parents := [mtn_element(document, 'mtn-video')!, mtn_element(document, 'mtn-audio')!]
	for index in 0 .. 2 { _ = mtn_media(document, index, probe)! }
	mut elements := []&dom.Element{}
	mut originals := [][]&dom.Attr_{}
	mut models := []&html.HTMLTrackElementModel{}
	names := ['kind', 'label', 'srclang', 'src', 'id']
	for index in 0 .. 4 {
		mut element := document.create_element_ns(dom.namespace_html_uri, 'track')!
		values := ['captions', 'Actual ${index}', 'de', 'actual-${index}.vtt', 'actual-track-${index}']
		foreign_values := ['metadata', 'Foreign ${index}', 'zz', 'https://foreign-track.example.test/${index}.vtt', 'foreign-track-${index}']
		for field, name in names {
			if index < 2 { element.set_attribute_value(name, values[field]) }
			element.set_attribute_ns_for_bindings(mtn_foreign, name, foreign_values[field])!
			if index >= 2 { element.set_attribute_value(name, values[field]) }
			element.set_attribute_ns_for_bindings(mtn_prefixed, 'p:${name}', 'prefixed-${name}-${index}')!
		}
		element.set_attribute_value('data-mtn-owner', '${index}')
		track_dom := unsafe { &dom.HTMLTrackElement(element) }
		assert track_dom.track_element_model_ == unsafe { nil }
		mut parent := parents[index % 2].as_node()
		parent.append_child(element.as_node())!
		assert track_dom.track_element_model_ == unsafe { nil }
		mut attributes := []&dom.Attr_{}
		for name in names {
			for namespace_index in 0 .. 3 {
				namespace := match namespace_index { 0 { ?string(none) } 1 { ?string(mtn_foreign) } else { ?string(mtn_prefixed) } }
				attributes << mtn_attribute(element, namespace, name)!
			}
		}
		mut model := html.html_track_element_model_for_dom_element(track_dom)
		assert model.track.kind() == .captions && model.track.label() == 'Actual ${index}'
		assert model.track.language() == 'de' && model.track.id() == 'actual-track-${index}'
		assert model.ready_state() == .none && model.track.mode() == .disabled
		model.set_fetch_hook(fn [probe] (url dom.URL, cors html.CORSSettingAttribute) !html.TextTrackResourceResponse {
			mut observed := unsafe { &MtnProbe(probe) }
			observed.urls << url.serialize()
			observed.cors << cors
			return html.TextTrackResourceResponse{ body: 'WEBVTT\n\nowner-cue\n00:00.000 --> 00:01.250\nactual track owner\n' }
		})
		// The current DOM bridge forwards this concrete HTML hook explicitly.
		html.html_track_element_inserted(track_dom)
		assert model.track.mode() == .hidden && model.ready_state() == .loaded
		assert model.event_count('load') == 1 && model.event_count('error') == 0
		assert model.track.cues().length() == 1
		cue := model.track.cues().item(0) or { panic('Missing real owner cue') }
		assert cue.id() == 'owner-cue' && cue.text() == 'actual track owner'
		assert probe.urls[index] == 'https://track-namespace.example.test/base/actual-${index}.vtt'
		assert probe.cors[index] == if index % 2 == 0 { html.CORSSettingAttribute.use_credentials } else { .anonymous }
		elements << element
		originals << attributes
		models << model
	}
	mut app, mut runtime := mtn_bind(owner, document)!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate_host('mtnTracks.length===4&&mtnPlayers[0].crossOrigin==="use-credentials"&&mtnPlayers[1].crossOrigin==="anonymous"')! == 'true'
	// Selector results are in tree order: video children 0/2, then audio 1/3.
	for facade_index, index in [0, 2, 1, 3] {
		projection := if index < 2 {
			['captions', 'Actual ${index}', 'de', 'actual-${index}.vtt', 'actual-track-${index}']
		} else {
			['metadata', 'Foreign ${index}', 'zz', 'https://foreign-track.example.test/${index}.vtt', 'foreign-track-${index}']
		}
		track := 'mtnTracks[${facade_index}]'
		for field, name in names {
			assert runtime.evaluate_host('${track}.getAttribute("${name}")==="${projection[field]}"')! == 'true'
		}
		assert runtime.evaluate_host('${track}.setAttribute("data-owner-observed","yes");document.querySelectorAll("track[data-mtn-owner]")[${facade_index}]===${track}')! == 'true'
		mtn_flush(document, runtime)!
		element := elements[index]
		null_values := ['captions', 'Actual ${index}', 'de', 'actual-${index}.vtt', 'actual-track-${index}']
		foreign_values := ['metadata', 'Foreign ${index}', 'zz', 'https://foreign-track.example.test/${index}.vtt', 'foreign-track-${index}']
		for field, name in names {
			for namespace_index in 0 .. 3 {
				namespace := match namespace_index { 0 { ?string(none) } 1 { ?string(mtn_foreign) } else { ?string(mtn_prefixed) } }
				attribute := originals[index][field * 3 + namespace_index]
				assert voidptr(mtn_attribute(element, namespace, name)!) == voidptr(attribute)
				assert voidptr(attribute.owner_element() or { panic('Lost track Attr owner') }) == voidptr(element)
				assert attribute.local_name() == name
				if namespace_index == 0 {
					assert attribute.namespace_uri() == none
				} else {
					assert (attribute.namespace_uri() or { '' }) == (namespace or { '' })
				}
				if namespace_index == 2 {
					assert attribute.name() == 'p:${name}' && (attribute.prefix() or { '' }) == 'p'
					assert attribute.value() == 'prefixed-${name}-${index}'
				} else {
					assert attribute.name() == name && attribute.prefix() == none
					assert attribute.value() == if namespace_index == 0 { null_values[field] } else { foreign_values[field] }
				}
			}
		}
		assert models[index].ready_state() == .loaded && models[index].event_count('load') == 1
		assert models[index].track.kind() == .captions && models[index].track.label() == 'Actual ${index}'
		assert models[index].track.language() == 'de' && models[index].track.id() == 'actual-track-${index}'
	}
	assert runtime.evaluate_host('mtnResult.textContent="namespace tracks loaded";mtnResult.style.color="rgb(51,62,73)";document.querySelector("#mtn-result")===mtnResult')! == 'true'
	mtn_flush(document, runtime)!
	app.relayout(320, 240 + app.chrome_height())
	assert app.paint_commands.any(it.kind == 'draw_text' && it.text == 'namespace tracks loaded' && it.color == 'rgb(51 62 73)')
	mtn_drain(document)
	assert probe.urls.len == 4 && probe.media_fetches == 0
	for index in 0 .. 2 {
		media := mtn_media(document, index, probe)!
		assert media.paused() && media.current_src() == '' && media.current_time() == 0
		assert media.network_state() == .empty && media.ready_state() == .have_nothing
		for event in ['loadstart', 'play', 'playing', 'pause', 'emptied', 'error'] { assert media.event_count(event) == 0 }
	}
	mtn_balance(app, document, runtime)
}

fn test_real_track_missing_empty_and_foreign_only_sources_fail_without_fetching_document_url() {
	$if !darwin { return }
	owner, mut document := mtn_document()!
	probe := &MtnProbe{}
	parents := [mtn_element(document, 'mtn-video')!, mtn_element(document, 'mtn-audio')!]
	for index in 0 .. 2 { _ = mtn_media(document, index, probe)! }
	mut elements := []&dom.Element{}
	mut originals := [][]&dom.Attr_{}
	mut original_values := [][]string{}
	mut models := []&html.HTMLTrackElementModel{}
	for index in 0 .. 6 {
		mut element := document.create_element_ns(dom.namespace_html_uri, 'track')!
		for name, value in {'kind': 'metadata', 'label': 'Foreign only', 'srclang': 'zz', 'id': 'foreign-only-${index}'} {
			element.set_attribute_ns_for_bindings(mtn_foreign, name, value)!
		}
		if index !in [2, 3] {
			element.set_attribute_ns_for_bindings(mtn_foreign, 'src', 'https://foreign-track.example.test/must-not-fetch-${index}.vtt')!
		}
		if index >= 4 { element.set_attribute_value('src', '') }
		element.set_attribute_ns_for_bindings(mtn_prefixed, 'p:src', 'https://prefixed-track.example.test/must-not-fetch.vtt')!
		element.set_attribute_value('data-mtn-owner', '${index}')
		track_dom := unsafe { &dom.HTMLTrackElement(element) }
		assert track_dom.track_element_model_ == unsafe { nil }
		mut parent := parents[index % 2].as_node()
		parent.append_child(element.as_node())!
		assert track_dom.track_element_model_ == unsafe { nil }
		attributes := element.attribute_list() or { panic('Missing initial track attributes') }
		originals << attributes.attrs.clone()
		original_values << attributes.attrs.map(it.value())
		mut model := html.html_track_element_model_for_dom_element(track_dom)
		assert model.track.kind() == .subtitles && model.track.label() == ''
		assert model.track.language() == '' && model.track.id() == ''
		assert model.ready_state() == .none && model.track.mode() == .disabled
		model.set_fetch_hook(fn [probe] (url dom.URL, cors html.CORSSettingAttribute) !html.TextTrackResourceResponse {
			mut observed := unsafe { &MtnProbe(probe) }
			observed.urls << url.serialize()
			observed.cors << cors
			return html.TextTrackResourceResponse{ body: 'WEBVTT\n\n00:00.000 --> 00:01.000\nwrongly fetched\n' }
		})
		html.html_track_element_inserted(track_dom)
		assert model.track.mode() == .hidden && model.ready_state() == .error
		assert model.event_count('error') == 1 && model.event_count('load') == 0
		assert model.track.cues().length() == 0 && probe.urls.len == 0
		elements << element
		models << model
	}
	app, mut runtime := mtn_bind(owner, document)!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate_host('mtnTracks.length===6')! == 'true'
	for facade_index, index in [0, 2, 4, 1, 3, 5] {
		track := 'mtnTracks[${facade_index}]'
		assert runtime.evaluate_host('${track}.getAttribute("kind")==="metadata"&&${track}.getAttribute("label")==="Foreign only"&&${track}.getAttribute("srclang")==="zz"&&${track}.getAttribute("id")==="foreign-only-${index}"')! == 'true'
		if index in [2, 3] {
			assert runtime.evaluate_host('!${track}.hasAttribute("src")&&${track}.getAttribute("src")===null')! == 'true'
		} else {
			assert runtime.evaluate_host('${track}.getAttribute("src")==="https://foreign-track.example.test/must-not-fetch-${index}.vtt"')! == 'true'
		}
		prefixed := mtn_attribute(elements[index], mtn_prefixed, 'src')!
		foreign_src := elements[index].get_attribute_node_ns(mtn_foreign, 'src')
		assert runtime.evaluate_host('${track}.setAttribute("data-owner-observed","source rejected");document.querySelectorAll("track[data-mtn-owner]")[${facade_index}]===${track}')! == 'true'
		mtn_flush(document, runtime)!
		for attribute_index, original in originals[index] {
			assert voidptr(mtn_attribute(elements[index], original.namespace_uri(), original.local_name())!) == voidptr(original)
			assert voidptr(original.owner_element() or { panic('Lost rejected-source Attr owner') }) == voidptr(elements[index])
			assert original.value() == original_values[index][attribute_index]
		}
		assert voidptr(mtn_attribute(elements[index], mtn_prefixed, 'src')!) == voidptr(prefixed)
		assert prefixed.name() == 'p:src' && (prefixed.prefix() or { '' }) == 'p'
		if original := foreign_src {
			assert voidptr(mtn_attribute(elements[index], mtn_foreign, 'src')!) == voidptr(original)
			assert original.value() == 'https://foreign-track.example.test/must-not-fetch-${index}.vtt'
		}
		if index >= 4 {
			assert (elements[index].get_attribute_ns(none, 'src') or { panic('Missing empty null source') }) == ''
		} else {
			assert !elements[index].has_attribute_ns(none, 'src')
		}
		assert models[index].ready_state() == .error && models[index].event_count('error') == 1
		assert models[index].event_count('load') == 0 && models[index].track.cues().length() == 0
	}
	mtn_drain(document)
	assert probe.urls == [] && probe.cors == [] && probe.media_fetches == 0
	for index in 0 .. 2 {
		media := mtn_media(document, index, probe)!
		assert media.paused() && media.current_src() == '' && media.network_state() == .empty
		assert media.ready_state() == .have_nothing && media.current_time() == 0
		for event in ['loadstart', 'play', 'playing', 'pause', 'emptied', 'error'] { assert media.event_count(event) == 0 }
	}
	mtn_balance(app, document, runtime)
}
