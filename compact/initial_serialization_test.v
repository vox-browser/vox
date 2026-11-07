module main

import browserjs
import dom
import html
import platform
import x.json2

fn initial_serialization_trial(temporary bool) (string, i64) {
	mut document := dom.Document.create(dom.URL{value: 'https://initial-state.test/'})
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	mut markup := '<!doctype html><main id="host">'
	for i in 0 .. 256 {
		markup += '<span id="item-${i}" class="named" data-one="first" data-two="second" data-three="雪😀">text</span>'
	}
	html.parse_html_from_a_string(document, markup + '</main>')
	storage := document.native_storage()
	before := if storage != unsafe { nil } { storage.arena.usage().used } else { i64(0) }
	mut work := platform.ThreadScratchScope{}
	encoded := if temporary {
		state := compact_initial_state_text(document, 'https://initial-state.test/', [], .roots_and_ids)
		work = state.workspace
		state.text
	} else {
		json2.encode(javascript_initial_state_with_policy(document, 'https://initial-state.test/', [], .roots_and_ids))
	}
	growth := if storage != unsafe { nil } { storage.arena.usage().used - before } else { i64(0) }
	owner.finish()
	owned := encoded.clone()
	work.finish()
	document.finalize()
	document.release_native_storage()
	return owned, growth
}

fn test_native_initial_serialization_retires_metadata_graph_with_identical_json() {
	control, previous := initial_serialization_trial(false)
	actual, retained := initial_serialization_trial(true)
	assert actual == control
	$if prealloc {
		assert retained < 64 * 1024
		assert retained * 10 < previous
		println('Initial host serialization: retained=${retained} control=${previous} JSON_bytes=${actual.len}')
	}
}

fn test_initial_serialization_preserves_models_svg_metadata_and_jsc_copied_state() {
	mut document := dom.Document.create(dom.URL{value: 'https://initial-state.test/controls'})
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><input id="field" value="λ😀"><textarea id="area">雪</textarea><select id="choice"><option selected>Label</option></select><img id="picture" alt="Picture"><video id="clip"></video><svg><use id="graphic" xlink:href="#雪"/></svg>')
	state := compact_initial_state_text(document, 'https://initial-state.test/controls', [], .roots_and_ids)
	mut runtime := browserjs.Runtime.create()
	runtime.initialize_host_from_json('(function(state){globalThis.capturedInitial=state;})', state.text)!
	state.workspace.finish()
	owner.finish()
	churn := platform.begin_thread_scratch('initial host serialization overwrite')
	_ = []u8{len: 1024 * 1024, init: u8(0xa5)}
	churn.finish()
	defer {
		runtime.close()
		document.finalize()
		document.release_native_storage()
	}
	assert runtime.evaluate_host(r'Object.values(capturedInitial.elements).find(e=>e.id==="field").value')! == 'λ😀'
	assert runtime.evaluate_host(r'Object.values(capturedInitial.elements).find(e=>e.id==="area").value')! == '雪'
	assert runtime.evaluate_host(r'Object.values(capturedInitial.elements).find(e=>e.id==="choice").value')! == 'Label'
	assert runtime.evaluate_host(r'Object.values(capturedInitial.elements).find(e=>e.id==="graphic").attributeRecords.find(a=>a.localName==="href").namespaceURI')! == 'http://www.w3.org/1999/xlink'
	field := document.get_element_by_id('field') or { panic('missing input') }
	area := document.get_element_by_id('area') or { panic('missing textarea') }
	picture := document.get_element_by_id('picture') or { panic('missing image') }
	clip := document.get_element_by_id('clip') or { panic('missing video') }
	assert html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(field) }).value() == 'λ😀'
	assert html.html_text_area_element_model_for_dom_element(unsafe { &dom.HTMLTextAreaElement(area) }).value() == '雪'
	_ = html.html_image_element_complete(unsafe { &dom.HTMLImageElement(picture) })
	_ = html.html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(clip) }).current_decoded_image_frame()
	$if prealloc {
		storage := document.native_storage()
		assert storage.arena.contains(voidptr(html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(field) })))
		assert storage.arena.contains(voidptr(html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(picture) })))
	}
}

fn test_native_bootstrap_still_exposes_live_named_controls_after_transport_retirement() {
	mut document := dom.Document.create(dom.URL{value: 'https://initial-state.test/live'})
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><input id="field" value="before"><textarea id="area">seed</textarea><p id="label">Old</p><section><b class="late">Lazy</b></section>')
	mut runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, 'https://initial-state.test/live', [r'
if(field.value!=="before"||area.value!=="seed")throw new Error("initial controls");
field.value="after 雪😀";area.value="live λ";label.textContent="Updated";
if(document.querySelector(".late").parentElement.localName!=="section")throw new Error("lazy parent");
console.log("initial transport passed");
'], runtime, mut messages)
	owner.finish()
	defer {
		runtime.close()
		document.finalize()
		document.release_native_storage()
	}
	assert messages == ['initial transport passed']
	assert runtime.evaluate_host('field.value+"|"+area.value+"|"+label.textContent')! == 'after 雪😀|live λ|Updated'
}
