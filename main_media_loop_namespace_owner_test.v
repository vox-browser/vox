module main

import browserjs
import dom
import html
import page
import time

const mln_owner_first = 'urn:loop-owner-first'
const mln_owner_second = 'urn:loop-owner-second'

fn mln_owner_element(document &dom.Document, id string) !&dom.Element {
	return document.get_element_by_id(id) or { return error('Missing loop namespace element ${id}') }
}

fn mln_owner_attr(element &dom.Element, namespace ?string) !&dom.Attr_ {
	return element.get_attribute_node_ns(namespace, 'loop') or { return error('Missing loop namespace attribute') }
}

fn mln_owner_fixture() !(&BrowserApp, &dom.Document, &browserjs.Runtime) {
	mut owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><style>video{width:100px;height:40px}</style><main id="mln-parent"><video id="mln-video"></video><audio id="mln-audio"></audio></main>', dom.URL{
		value: 'https://loop-namespace.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	for index, id in ['mln-video', 'mln-audio'] {
		mut element := mln_owner_element(document, id)!
		if index == 1 { element.set_attribute_value('loop', 'initial null') }
		element.set_attribute_ns_for_bindings(mln_owner_first, 'loop', 'first ${id}')!
		if index == 0 { element.set_attribute_value('loop', 'initial null') }
		element.set_attribute_ns_for_bindings(mln_owner_second, 'loop', 'second ${id}')!
	}
	runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'globalThis.mlnParent=document.getElementById("mln-parent");globalThis.mlnVideo=document.getElementById("mln-video");globalThis.mlnAudio=document.getElementById("mln-audio");void mlnVideo.paused;void mlnAudio.paused;0'], runtime, mut messages)
	assert messages == []
	app := &BrowserApp{ page_model: owner, document: document, js_runtime: runtime, viewport_width: 320, viewport_height: 240 }
	return app, document, runtime
}

fn mln_owner_flush(document &dom.Document, runtime &browserjs.Runtime) ! {
	snapshot := runtime.evaluate_host('__ladybirdFinalize()')!
	mut messages := []string{}
	apply_javascript_state(document, snapshot, runtime.canvas_elements_for_binding(), mut messages)
	assert messages == []
	_ = runtime.evaluate_host('__ladybirdClearLogs();0')!
}

fn mln_owner_balance(app &BrowserApp, document &dom.Document, runtime &browserjs.Runtime) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0 && runtime.libjs_vm().interpreter_stack().depth() == 0
	assert app.js_messages == []
}

fn test_native_loop_owner_preserves_foreign_duplicates_through_getter_query_and_dirty_replay() {
	$if !darwin { return }
	mut app, mut document, mut runtime := mln_owner_fixture()!
	defer { runtime.close(); document.finalize() }
	for index, id in ['mln-video', 'mln-audio'] {
		element := mln_owner_element(document, id)!
		name := if index == 0 { 'mlnVideo' } else { 'mlnAudio' }
		first := mln_owner_attr(element, mln_owner_first)!
		second := mln_owner_attr(element, mln_owner_second)!
		original_null := mln_owner_attr(element, none)!
		mut media := html.html_media_element_for_dom_element(element) or { panic('Missing loop owner') }
		media.set_current_time(4)
		media.set_paused(false)
		assert runtime.evaluate_host('${name}.loop===true')! == 'true'
		assert runtime.evaluate_host('${name}.loop=false;${name}.setAttribute("data-dirty","first removal");document.querySelector("#${id}")===${name}&&!${name}.loop&&${name}.hasAttribute("loop")&&${name}.getAttribute("loop")==="first ${id}"')! == 'true'
		mln_owner_flush(document, runtime)!
		assert !media.loop() && !element.has_attribute_ns(none, 'loop') && original_null.owner_element() == none
		assert voidptr(mln_owner_attr(element, mln_owner_first)!) == voidptr(first)
		assert voidptr(mln_owner_attr(element, mln_owner_second)!) == voidptr(second)
		assert first.value() == 'first ${id}' && second.value() == 'second ${id}'
		assert runtime.evaluate_host('${name}.loop=true;${name}.loop&&${name}.getAttribute("loop")==="first ${id}"')! == 'true'
		new_null := mln_owner_attr(element, none)!
		assert media.loop() && new_null.value() == '' && voidptr(new_null) != voidptr(original_null)
		assert runtime.evaluate_host('${name}.loop=false;${name}.loop=false;${name}.setAttribute("data-dirty","repeated removal");!${name}.loop&&${name}.getAttribute("loop")==="first ${id}"')! == 'true'
		mln_owner_flush(document, runtime)!
		assert !media.loop() && !element.has_attribute_ns(none, 'loop') && new_null.owner_element() == none
		assert element.get_attribute_names().filter(it == 'loop').len == 2
		assert voidptr(mln_owner_attr(element, mln_owner_first)!) == voidptr(first)
		assert voidptr(mln_owner_attr(element, mln_owner_second)!) == voidptr(second)
		assert first.value() == 'first ${id}' && second.value() == 'second ${id}'
		assert media.current_time() == 4 && !media.paused() && !media.muted() && media.volume() == 1
		assert media.current_src() == '' && media.network_state() == .empty && media.ready_state() == .have_nothing
		for event in ['seeking', 'seeked', 'timeupdate', 'ended', 'play', 'pause', 'volumechange', 'loadstart'] { assert media.event_count(event) == 0 }
	}
	app.relayout(320, 240 + app.chrome_height())
	mln_owner_balance(app, document, runtime)
}

fn test_native_loop_lazy_owner_replays_qualified_removal_then_null_reflection_across_reinsertion() {
	$if !darwin { return }
	mut app, mut document, mut runtime := mln_owner_fixture()!
	defer { runtime.close(); document.finalize() }
	mut late := document.create_element('video')!
	late.set_attribute_value('id', 'mln-late')
	late.set_attribute_ns_for_bindings(mln_owner_first, 'loop', 'late first')!
	late.set_attribute_ns_for_bindings(mln_owner_second, 'loop', 'late second')!
	first := mln_owner_attr(late, mln_owner_first)!
	second := mln_owner_attr(late, mln_owner_second)!
	parent := mln_owner_element(document, 'mln-parent')!
	mut parent_node := parent.as_node()
	parent_node.append_child(late.as_node())!
	assert runtime.evaluate_host('globalThis.mlnLate=document.querySelector("#mln-late");!mlnLate.loop&&mlnLate.getAttribute("loop")==="late first"')! == 'true'
	media := html.html_media_element_for_dom_element(late) or { panic('Missing lazy loop owner') }
	assert !media.loop()
	assert runtime.evaluate_host('mlnLate.loop=true;mlnLate.removeAttribute("loop");mlnLate.loop&&mlnLate.getAttribute("loop")==="late second"')! == 'true'
	assert first.owner_element() == none && media.loop()
	assert voidptr(mln_owner_attr(late, mln_owner_second)!) == voidptr(second)
	null_attr := mln_owner_attr(late, none)!
	assert null_attr.value() == ''
	assert runtime.evaluate_host('mlnLate.loop=false;mlnLate.setAttribute("data-dirty","after qualified removal");document.querySelector("#mln-late")===mlnLate&&!mlnLate.loop&&mlnLate.getAttribute("loop")==="late second"')! == 'true'
	mln_owner_flush(document, runtime)!
	assert !media.loop() && null_attr.owner_element() == none && !late.has_attribute_ns(none, 'loop')
	assert second.value() == 'late second' && voidptr(mln_owner_attr(late, mln_owner_second)!) == voidptr(second)
	assert runtime.evaluate_host('mlnLate.remove();document.querySelector("#mln-late")===null&&!mlnLate.loop')! == 'true'
	assert !late.as_node().is_connected()
	assert runtime.evaluate_host('mlnParent.appendChild(mlnLate);document.querySelector("#mln-late")===mlnLate&&!mlnLate.loop&&mlnLate.getAttribute("loop")==="late second"')! == 'true'
	assert voidptr(mln_owner_element(document, 'mln-late')!) == voidptr(late)
	assert voidptr(html.html_media_element_for_dom_element(late)?) == voidptr(media)
	assert voidptr(mln_owner_attr(late, mln_owner_second)!) == voidptr(second)
	assert second.value() == 'late second' && !late.has_attribute_ns(none, 'loop') && !media.loop()
	assert media.paused() && media.current_time() == 0 && media.current_src() == '' && media.network_state() == .empty
	for event in ['seeking', 'seeked', 'timeupdate', 'ended', 'play', 'pause', 'loadstart'] { assert media.event_count(event) == 0 }
	mln_owner_flush(document, runtime)!
	app.relayout(320, 240 + app.chrome_height())
	mln_owner_balance(app, document, runtime)
}
