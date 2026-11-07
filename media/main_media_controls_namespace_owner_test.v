module main

import browserjs
import css
import dom
import html
import page
import time

const mcn_owner_namespace = 'urn:controls-namespace-owner'
const mcn_owner_markup = '<!doctype html><style>html,body{margin:0}audio,video{display:block;width:140px;height:40px}</style><video id="mcn-video"></video><audio id="mcn-audio"></audio><div id="mcn-ordinary" controls="ordinary value"></div><svg width="160" height="40"><audio id="mcn-svg-audio" controls="SVG audio value"></audio><video id="mcn-svg-video" controls="SVG video value"></video></svg>'

fn mcn_owner_element(document &dom.Document, id string) !&dom.Element {
	return document.get_element_by_id(id) or { return error('missing controls namespace element ${id}') }
}

fn mcn_owner_fixture() !(&BrowserApp, &dom.Document, &browserjs.Runtime) {
	mut owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time(mcn_owner_markup, dom.URL{
		value: 'https://controls-namespace-owner.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	for id in ['mcn-video', 'mcn-audio'] {
		mut element := mcn_owner_element(document, id)!
		// The qualified name is deliberately unprefixed, while the namespace is non-null.
		element.set_attribute_ns_for_bindings(mcn_owner_namespace, 'controls', 'foreign ${id}')!
		assert element.has_attribute('controls') && !element.has_attribute_ns(none, 'controls')
		assert element.get_attribute_ns(mcn_owner_namespace, 'controls') or { '' } == 'foreign ${id}'
	}
	runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
globalThis.mcnVideo=document.getElementById("mcn-video");globalThis.mcnAudio=document.getElementById("mcn-audio");globalThis.mcnSVGAudio=document.getElementById("mcn-svg-audio");globalThis.mcnSVGVideo=document.getElementById("mcn-svg-video");globalThis.mcnOrdinary=document.getElementById("mcn-ordinary");void mcnVideo.controls;void mcnAudio.controls;0
'], runtime, mut messages)
	assert messages == []
	app := &BrowserApp{
		page_model: owner
		document: document
		js_runtime: runtime
		viewport_width: 320
		viewport_height: 240
	}
	return app, document, runtime
}

fn mcn_owner_balance(runtime &browserjs.Runtime, document &dom.Document) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_native_controls_namespace_owner_uses_null_namespace_for_initial_widgets() {
	$if !darwin { return }
	mut app, mut document, mut runtime := mcn_owner_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	video := mcn_owner_element(document, 'mcn-video')!
	audio := mcn_owner_element(document, 'mcn-audio')!
	assert runtime.evaluate_host('!mcnVideo.controls&&!mcnAudio.controls')! == 'true'
	app.relayout(320, 240 + app.chrome_height())
	assert document.layout_is_up_to_date() && document.paintable_box() != none
	for element in [video, audio] {
		assert element.is_html_element() && element.has_attribute('controls')
		assert !element.has_attribute_ns(none, 'controls') && element.shadow_root() == none
	}
	assert audio.as_node().unsafe_layout_node() == none
	assert runtime.evaluate_host('mcnVideo.controls=true;mcnAudio.controls=true;mcnVideo.controls&&mcnAudio.controls')! == 'true'
	for index, element in [video, audio] {
		id := if index == 0 { 'mcn-video' } else { 'mcn-audio' }
		assert element.get_attribute_ns(none, 'controls') or { 'missing' } == ''
		assert element.get_attribute_ns(mcn_owner_namespace, 'controls') or { '' } == 'foreign ${id}'
	}
	app.relayout(320, 240 + app.chrome_height())
	assert audio.as_node().unsafe_layout_node() != none
	for index, element in [video, audio] {
		id := if index == 0 { 'mcn-video' } else { 'mcn-audio' }
		assert element.get_attribute_ns(mcn_owner_namespace, 'controls') or { '' } == 'foreign ${id}'
		shadow := element.shadow_root() or { panic('null-namespace controls did not create initial widgets') }
		assert shadow.is_user_agent_internal() && shadow.mode() == .closed
		assert element.shadow_root_for_bindings() == none
		selector := if index == 0 { '.container.video' } else { '.container.audio' }
		container := css.query_selector(shadow.as_node(), selector) or { panic('missing controls container') }
		assert container.as_node().unsafe_layout_node() != none
		assert css.query_selector(shadow.as_node(), '.timeline-track') != none
		assert css.query_selector(shadow.as_node(), '.play-pause-button') != none
	}
	// Widget teardown and compact dirty-snapshot removal of duplicate qualified names remain open.
	assert app.js_messages == []
	mcn_owner_balance(runtime, document)
}

fn test_native_controls_namespace_owner_excludes_svg_and_ordinary_elements() {
	$if !darwin { return }
	mut app, mut document, mut runtime := mcn_owner_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host('!("controls" in mcnSVGAudio)&&!("controls" in mcnSVGVideo)&&!("controls" in mcnOrdinary)')! == 'true'
	app.relayout(320, 240 + app.chrome_height())
	assert document.layout_is_up_to_date() && document.paintable_box() != none
	for id in ['mcn-svg-audio', 'mcn-svg-video', 'mcn-ordinary'] {
		element := mcn_owner_element(document, id)!
		assert element.has_attribute_ns(none, 'controls') && element.shadow_root() == none
		assert html.html_media_element_for_dom_element(element) == none
		if id != 'mcn-ordinary' { assert !element.is_html_element() }
	}
	assert runtime.evaluate_host('!("controls" in mcnSVGAudio)&&!("controls" in mcnSVGVideo)&&!("controls" in mcnOrdinary)')! == 'true'
	assert app.js_messages == []
	mcn_owner_balance(runtime, document)
}
