module main

import browserjs
import dom
import html
import page
import time

const msn_foreign = 'urn:media-source-owner'
const msn_prefixed = 'urn:media-source-prefixed'

@[heap]
struct MsnProbe {
mut:
	urls []string
	owners []string
}

fn msn_element(document &dom.Document, id string) !&dom.Element {
	return document.get_element_by_id(id) or { return error('Missing media source namespace element ${id}') }
}

fn msn_attribute(element &dom.Element, namespace ?string) !&dom.Attr_ {
	return element.get_attribute_node_ns(namespace, 'src') or { return error('Missing media source namespace attribute') }
}

fn msn_document(markup string) !(&page.Page, &dom.Document) {
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{
		value: 'https://media-source-namespace.example.test/base/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	assert document.is_fully_active()
	return owner, document
}

fn msn_bind(owner &page.Page, document &dom.Document, script string) !(&BrowserApp, &browserjs.Runtime) {
	runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [script], runtime, mut messages)
	assert messages == []
	app := &BrowserApp{ page_model: owner, document: document, js_runtime: runtime, viewport_width: 320, viewport_height: 240 }
	return app, runtime
}

fn msn_flush(document &dom.Document, runtime &browserjs.Runtime) ! {
	snapshot := runtime.evaluate_host('__ladybirdFinalize()')!
	mut messages := []string{}
	apply_javascript_runtime_state(document, snapshot, runtime, mut messages)
	assert messages == []
	_ = runtime.evaluate_host('__ladybirdClearLogs();0')!
}

fn msn_drain(document &dom.Document) {
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

fn msn_balance(app &BrowserApp, document &dom.Document, runtime &browserjs.Runtime) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0 && runtime.libjs_vm().interpreter_stack().depth() == 0
	assert app.js_messages == []
}

fn test_native_load_uses_initial_null_namespace_source_without_selecting_foreign_attributes() {
	$if !darwin { return }
	owner, mut document := msn_document('<!doctype html><style>html,body{margin:0}video{display:block;width:80px;height:30px}</style><video id="msn-video-foreign" preload="none"></video><audio id="msn-audio-foreign" preload="none"></audio><video id="msn-video-first" preload="none"></video><audio id="msn-audio-first" preload="none"></audio><video id="msn-video-last" preload="none"></video><audio id="msn-audio-last" preload="none"></audio><p id="msn-result">waiting</p>')!
	ids := ['msn-video-foreign', 'msn-audio-foreign', 'msn-video-first', 'msn-audio-first', 'msn-video-last', 'msn-audio-last']
	// Seed every source slot before MediaElementHost materializes the model caches.
	for index, id in ids {
		mut element := msn_element(document, id)!
		if index in [2, 3] { element.set_attribute_value('src', '/actual-${index}.mp4') }
		element.set_attribute_ns_for_bindings(msn_foreign, 'src', 'https://foreign-source.example.test/${index}.mp4')!
		if index in [4, 5] { element.set_attribute_value('src', '/actual-${index}.mp4') }
		element.set_attribute_ns_for_bindings(msn_prefixed, 'p:src', 'https://prefixed-source.example.test/${index}.mp4')!
	}
	mut app, mut runtime := msn_bind(owner, document, r'globalThis.msnPlayers=["msn-video-foreign","msn-audio-foreign","msn-video-first","msn-audio-first","msn-video-last","msn-audio-last"].map(id=>document.getElementById(id));globalThis.msnResult=document.getElementById("msn-result");for(const player of msnPlayers)void player.paused;0')!
	defer { runtime.close(); document.finalize() }
	probe := &MsnProbe{}
	for index, id in ids {
		element := msn_element(document, id)!
		foreign := msn_attribute(element, msn_foreign)!
		prefixed := msn_attribute(element, msn_prefixed)!
		null_slot := element.get_attribute_node_ns(none, 'src')
		mut media := html.html_media_element_for_dom_element(element) or { panic('Missing initial source owner') }
		mime := if index % 2 == 0 { 'video/mp4' } else { 'audio/webm' }
		media.set_fetch_hook(fn [probe, id, mime] (url dom.URL, offset u64) !html.MediaResourceResponse {
			assert offset == 0
			mut observed := unsafe { &MsnProbe(probe) }
			observed.urls << url.serialize()
			observed.owners << id
			return html.MediaResourceResponse{ mime_type: mime, duration: 4, buffered_end: 4 }
		})
		before_fetches := probe.urls.len
		expected := if index < 2 { '' } else { 'https://media-source-namespace.example.test/actual-${index}.mp4' }
		projection := if index in [2, 3] { '/actual-${index}.mp4' } else { 'https://foreign-source.example.test/${index}.mp4' }
		player := 'msnPlayers[${index}]'
		assert runtime.evaluate_host('${player}.load()===undefined&&${player}.currentSrc==="${expected}"&&${player}.paused&&${player}.getAttribute("src")==="${projection}"')! == 'true'
		msn_drain(document)
		assert media.current_src() == expected && media.paused() && media.current_time() == 0
		if index < 2 {
			assert probe.urls.len == before_fetches && null_slot == none
			assert media.network_state() == .empty && media.ready_state() == .have_nothing
			assert media.event_count('loadstart') == 0
		} else {
			assert probe.urls.len == before_fetches + 1 && probe.urls.last() == expected && probe.owners.last() == id
			assert media.network_state() == .idle && media.ready_state() == .have_enough_data && media.error() == none
			assert media.event_count('loadstart') == 1 && media.event_count('loadeddata') == 1
			original := null_slot or { panic('Missing original null source') }
			assert voidptr(msn_attribute(element, none)!) == voidptr(original) && original.value() == '/actual-${index}.mp4'
		}
		assert runtime.evaluate_host('${player}.setAttribute("data-dirty","source observed");document.querySelector("#${id}")===${player}&&${player}.currentSrc==="${expected}"&&${player}.getAttribute("src")==="${projection}"')! == 'true'
		msn_flush(document, runtime)!
		assert media.current_src() == expected
		assert voidptr(msn_attribute(element, msn_foreign)!) == voidptr(foreign)
		assert foreign.value() == 'https://foreign-source.example.test/${index}.mp4' && foreign.owner_element() != none
		assert voidptr(msn_attribute(element, msn_prefixed)!) == voidptr(prefixed)
		assert prefixed.name() == 'p:src' && (prefixed.prefix() or { '' }) == 'p' && prefixed.value() == 'https://prefixed-source.example.test/${index}.mp4'
		for name in ['play', 'playing', 'pause', 'emptied', 'error'] { assert media.event_count(name) == 0 }
	}
	assert probe.owners == ids[2..] && probe.urls.len == 4
	assert runtime.evaluate_host('msnResult.textContent="namespace source selected";msnResult.style.color="rgb(41,42,43)";document.querySelector("#msn-result")===msnResult')! == 'true'
	msn_flush(document, runtime)!
	app.relayout(320, 240 + app.chrome_height())
	assert app.paint_commands.any(it.kind == 'draw_text' && it.text == 'namespace source selected' && it.color == 'rgb(41 42 43)')
	msn_balance(app, document, runtime)
}

fn test_native_load_collects_actual_child_source_null_slots_in_tree_order() {
	$if !darwin { return }
	owner, mut document := msn_document('<!doctype html><video id="msn-video-children" preload="none"></video><audio id="msn-audio-children" preload="none"></audio>')!
	ids := ['msn-video-children', 'msn-audio-children']
	mut chosen_elements := []&dom.Element{}
	mut ignored_elements := []&dom.Element{}
	for index, id in ids {
		mut element := msn_element(document, id)!
		element.set_attribute_ns_for_bindings(msn_foreign, 'src', '/foreign-parent-${index}.mp4')!
		mut ignored := document.create_element('source')!
		ignored.set_attribute_ns_for_bindings(msn_foreign, 'src', '/foreign-child-${index}.mp4')!
		ignored.set_attribute_ns_for_bindings(msn_prefixed, 'p:src', '/prefixed-child-${index}.mp4')!
		mut chosen := document.create_element('source')!
		if index == 1 { chosen.set_attribute_value('src', '/chosen-${index}.mp4') }
		chosen.set_attribute_ns_for_bindings(msn_foreign, 'src', '/foreign-shadow-${index}.mp4')!
		if index == 0 { chosen.set_attribute_value('src', '/chosen-${index}.mp4') }
		chosen.set_attribute_ns_for_bindings(msn_prefixed, 'p:src', '/prefixed-chosen-${index}.mp4')!
		mut later := document.create_element('source')!
		later.set_attribute_value('src', '/later-${index}.mp4')
		mut node := element.as_node()
		for child in [ignored, chosen, later] { node.append_child(child.as_node())! }
		ignored_elements << ignored
		chosen_elements << chosen
	}
	app, mut runtime := msn_bind(owner, document, r'globalThis.msnChildren=[document.getElementById("msn-video-children"),document.getElementById("msn-audio-children")];for(const player of msnChildren)void player.paused;0')!
	defer { runtime.close(); document.finalize() }
	probe := &MsnProbe{}
	for index, id in ids {
		element := msn_element(document, id)!
		chosen := chosen_elements[index]
		ignored := ignored_elements[index]
		parent_foreign := msn_attribute(element, msn_foreign)!
		ignored_foreign := msn_attribute(ignored, msn_foreign)!
		chosen_foreign := msn_attribute(chosen, msn_foreign)!
		chosen_null := msn_attribute(chosen, none)!
		chosen_prefixed := msn_attribute(chosen, msn_prefixed)!
		mut media := html.html_media_element_for_dom_element(element) or { panic('Missing child source owner') }
		media.set_fetch_hook(fn [probe, id] (url dom.URL, offset u64) !html.MediaResourceResponse {
			assert offset == 0
			mut observed := unsafe { &MsnProbe(probe) }
			observed.urls << url.serialize()
			observed.owners << id
			return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 6, buffered_end: 6 }
		})
		// This existing hook collects current children before the first explicit load.
		// No live src cache refresh or automatic mutation notification is assumed.
		media.children_changed(dom.ChildrenChangedMetadata{ type_: .inserted, node: chosen.as_node() })
		assert probe.urls.len == index
		expected := 'https://media-source-namespace.example.test/chosen-${index}.mp4'
		player := 'msnChildren[${index}]'
		assert runtime.evaluate_host('${player}.load()===undefined&&${player}.currentSrc==="${expected}"&&${player}.readyState===4&&${player}.getAttribute("src")==="/foreign-parent-${index}.mp4"')! == 'true'
		msn_drain(document)
		assert probe.urls.len == index + 1 && probe.urls[index] == expected && probe.owners[index] == id
		assert media.current_src() == expected && media.ready_state() == .have_enough_data && media.network_state() == .idle
		assert runtime.evaluate_host('${player}.setAttribute("data-dirty","child selected");document.querySelector("#${id}")===${player}&&${player}.currentSrc==="${expected}"')! == 'true'
		msn_flush(document, runtime)!
		assert probe.urls.len == index + 1 && media.current_src() == expected
		assert voidptr(msn_attribute(element, msn_foreign)!) == voidptr(parent_foreign)
		assert parent_foreign.value() == '/foreign-parent-${index}.mp4' && !element.has_attribute_ns(none, 'src')
		assert voidptr(msn_attribute(ignored, msn_foreign)!) == voidptr(ignored_foreign) && ignored_foreign.value() == '/foreign-child-${index}.mp4'
		assert voidptr(msn_attribute(chosen, msn_foreign)!) == voidptr(chosen_foreign) && chosen_foreign.value() == '/foreign-shadow-${index}.mp4'
		assert voidptr(msn_attribute(chosen, none)!) == voidptr(chosen_null) && chosen_null.value() == '/chosen-${index}.mp4'
		assert voidptr(msn_attribute(chosen, msn_prefixed)!) == voidptr(chosen_prefixed)
		assert chosen_prefixed.name() == 'p:src' && chosen_prefixed.value() == '/prefixed-chosen-${index}.mp4'
		assert media.paused() && media.current_time() == 0 && media.event_count('loadstart') == 1 && media.event_count('loadeddata') == 1
		for name in ['play', 'playing', 'pause', 'emptied', 'error'] { assert media.event_count(name) == 0 }
	}
	assert probe.urls.len == 2
	msn_balance(app, document, runtime)
}
