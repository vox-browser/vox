module main

import browserjs
import dom
import encoding.base64
import html
import page
import time
import x.json2

const media_video_namespace_owner_markup = '<!doctype html><video id="namespace-html"></video><svg><video id="namespace-svg"></video></svg><canvas id="namespace-canvas" width="2" height="2"></canvas>'

fn media_video_namespace_owner_document() !&dom.Document {
	owner := page.Page.create(1)!
	return parse_browser_navigation_document_for_page_with_response_time(media_video_namespace_owner_markup,
		dom.URL{ value: 'https://video-namespace-owner.example.test/' }, none, none,
		unsafe { &dom.Page(owner) }, time.sys_mono_now())
}

fn media_video_namespace_owner_set_frame(document &dom.Document) !&dom.Bitmap_ {
	element := document.get_element_by_id('namespace-html') or { return error('Missing HTML video') }
	assert element.is_html_element() && element.local_name() == 'video'
	mut model := html.html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
	bitmap := &dom.Bitmap_{
		width:                    2
		height:                   2
		pitch:                    8
		data:                     [u8(255), 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255,
			255, 255]
		native_rows_are_top_down: true
	}
	model.set_current_frame(bitmap)
	mut media := model.media
	media.set_ready_state(.have_current_data)
	frame := model.current_decoded_image_frame() or { return error('Missing decoded HTML frame') }
	assert voidptr(frame.bitmap()) == voidptr(bitmap)
	return bitmap
}

fn media_video_namespace_owner_element_state(state map[string]json2.Any, id string) !map[string]json2.Any {
	value := state['elements'] or { return error('Missing initial elements') }
	if value !is map[string]json2.Any { return error('Invalid initial elements') }
	for _, item in value as map[string]json2.Any {
		if item is map[string]json2.Any {
			entry := item as map[string]json2.Any
			if (json_string_property(entry, 'id') or { '' }) == id { return entry }
		}
	}
	return error('Missing initial element ${id}')
}

fn test_native_video_page_installers_and_bootstrap_distinguish_parsed_html_and_svg_video() {
	$if !darwin {
		return
	}
	mut document := media_video_namespace_owner_document()!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	html_video := document.get_element_by_id('namespace-html')?
	svg_video := document.get_element_by_id('namespace-svg')?
	assert html_video.is_html_element() && html_video.local_name() == 'video'
	assert !svg_video.is_html_element() && svg_video.local_name() == 'video'
	assert svg_video.namespace_uri()? == 'http://www.w3.org/2000/svg'
	assert html.html_media_element_for_dom_element(svg_video) == none
	// Exercise both actual page installers without any transport or decoder input.
	// Only the concrete HTML video can acquire a translated video model.
	install_video_poster_fetch_hooks(document)
	install_local_video_frames(document, document.url.serialize(), media_video_namespace_owner_markup)
	model := html.html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(html_video) })
	assert model.current_decoded_image_frame() == none
	bitmap := media_video_namespace_owner_set_frame(document)!
	state := javascript_initial_state(document, document.url.serialize(), [])
	html_state := media_video_namespace_owner_element_state(state, 'namespace-html')!
	svg_state := media_video_namespace_owner_element_state(state, 'namespace-svg')!
	assert json_int_property(html_state, 'readyState')? == 2
	assert json_int_property(html_state, 'videoWidth')? == 2 && json_int_property(html_state, 'videoHeight')? == 2
	assert json_string_property(html_state, 'videoPixels')? == base64.encode(bitmap.data)
	assert json_string_property(svg_state, 'namespaceURI')? == 'http://www.w3.org/2000/svg'
	for name in ['readyState', 'videoWidth', 'videoHeight', 'videoPixels'] {
		assert name !in svg_state
	}
	mut messages := []string{}
	// Generic compact facades retain zero-valued own video placeholders; they
	// must not gain the native media prototype or pass its branded state getter.
	run_document_javascript(document, document.url.serialize(), [r'
globalThis.namespaceHTML=document.getElementById("namespace-html");globalThis.namespaceSVG=document.getElementById("namespace-svg");
globalThis.namespaceFramePassed=namespaceHTML instanceof HTMLMediaElement&&namespaceHTML.readyState===2&&namespaceHTML.videoWidth===2&&namespaceHTML.videoHeight===2&&!Object.hasOwn(namespaceHTML,"readyState")&&!(namespaceSVG instanceof HTMLMediaElement)&&namespaceSVG.readyState===0&&namespaceSVG.videoWidth===0&&namespaceSVG.videoHeight===0&&Object.hasOwn(namespaceSVG,"readyState")&&!("play" in namespaceSVG);
try{Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"readyState").get.call(namespaceSVG);namespaceFramePassed=false}catch(error){namespaceFramePassed=namespaceFramePassed&&error instanceof TypeError}
'], runtime, mut messages)
	assert messages == [] && runtime.evaluate_host('namespaceFramePassed')! == 'true'
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('namespaceHTML')!)!) == voidptr(html_video)
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('namespaceSVG')!)!) == voidptr(svg_video)
	mut app := &BrowserApp{
		page_model:      unsafe { &page.Page(document.page()) }
		document:        document
		js_runtime:      runtime
		viewport_width:  320
		viewport_height: 240
	}
	// Keep the parsed SVG video in the real retained renderer traversal too.
	app.relayout(320, 240 + app.chrome_height())
	assert document.layout_is_up_to_date() && document.paintable_box() != none
	assert app.paint_commands.len > 0 && app.js_messages == []
	assert app.paint_commands.filter(it.kind == 'draw_video').len == 1
	assert html.html_media_element_for_dom_element(svg_video) == none
	assert voidptr(model.current_decoded_image_frame()?.bitmap()) == voidptr(bitmap)
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_native_canvas_video_source_skips_svg_shortcut_and_keeps_html_decoded_frame_pixels() {
	$if !darwin {
		return
	}
	mut document := media_video_namespace_owner_document()!
	defer { document.finalize() }
	bitmap := media_video_namespace_owner_set_frame(document)!
	svg_video := document.get_element_by_id('namespace-svg')?
	mut canvas_element := document.get_element_by_id('namespace-canvas')?
	assert !svg_video.is_html_element() && svg_video.local_name() == 'video'
	assert canvas_element.is_html_element() && canvas_element.local_name() == 'canvas'
	fallback := [u8(19), 23, 29, 255, 31, 37, 41, 255, 43, 47, 53, 255, 59, 61, 67, 255]
	mut values := []json2.Any{cap: fallback.len}
	for value in fallback { values << json2.Any(int(value)) }
	mut state := {
		'canvasWidth':               json2.Any(2)
		'canvasHeight':              json2.Any(2)
		'canvasPixels':              json2.Any(values)
		'canvasPixelsTopDown':       json2.Any(false)
		'canvasPixelsPremultiplied': json2.Any(false)
		'canvasNative':              json2.Any(true)
		'canvasVideoSource':         json2.Any('namespace-svg')
	}
	// A same-named SVG element is not a decoded source. Preserve supplied pixels
	// and their row orientation rather than reading HTML-only model storage.
	apply_javascript_canvas_state(document, mut canvas_element, state)
	canvas := unsafe { &dom.HTMLCanvasElement(canvas_element) }
	fallback_surface := html.html_canvas_element_surface(canvas)?
	assert fallback_surface.width == 2 && fallback_surface.height == 2
	assert fallback_surface.data == fallback && !fallback_surface.native_rows_are_top_down
	assert html.html_media_element_for_dom_element(svg_video) == none
	// The existing matching-size HTML shortcut must still select the live frame.
	state['canvasVideoSource'] = json2.Any('namespace-html')
	apply_javascript_canvas_state(document, mut canvas_element, state)
	decoded_surface := html.html_canvas_element_surface(canvas)?
	assert decoded_surface.data == bitmap.data && decoded_surface.data != fallback
	assert decoded_surface.native_rows_are_top_down && decoded_surface.alpha_type == 1
	assert html.html_media_element_for_dom_element(svg_video) == none
}
