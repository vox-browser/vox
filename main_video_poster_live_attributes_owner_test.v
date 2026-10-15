module main

import browserjs
import dom
import html
import page
import time

@[heap]
struct MvplaProbe {
mut:
	urls []string
}

fn mvpla_flush(document &dom.Document, runtime &browserjs.Runtime) ! {
	snapshot := runtime.evaluate_host('__ladybirdFinalize()')!
	mut messages := []string{}
	apply_javascript_runtime_state(document, snapshot, runtime, mut messages)
	assert messages == []
	_ = runtime.evaluate_host('__ladybirdClearLogs();0')!
}

fn test_compact_video_poster_writes_reach_parsed_and_created_native_models() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	mut document := parse_browser_navigation_document_for_page_with_response_time(
		'<!doctype html><video id="mvpla-parsed" preload="none"></video>',
		dom.URL{ value: 'https://poster-owner.example/base/page.html' }, none, none,
		unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
globalThis.mvplaVideos=[document.getElementById("mvpla-parsed")];
const created=document.createElement("video");created.id="mvpla-created";
created.setAttribute("preload","none");document.body.appendChild(created);
mvplaVideos.push(created);0'], runtime, mut messages)
	assert messages == [] && runtime.evaluate_host('mvplaVideos.length===2')! == 'true'
	for index, id in ['mvpla-parsed', 'mvpla-created'] {
		element := document.get_element_by_id(id) or { panic('Missing native poster owner') }
		video_owner := unsafe { &dom.HTMLVideoElement(element) }
		mut model := html.html_video_element_model_for_dom_element(video_owner)
		probe := &MvplaProbe{}
		model.set_poster_fetch_hook(fn [probe] (url dom.URL) !&dom.Bitmap_ {
			mut observed := unsafe { &MvplaProbe(probe) }
			observed.urls << url.serialize()
			return &dom.Bitmap_{ width: 17, height: 9, pitch: 68, data: []u8{len: 17 * 9 * 4} }
		})
		assert runtime.evaluate_host('mvplaVideos[${index}].setAttribute("poster","first-${index}.png");0')! == '0'
		mvpla_flush(document, runtime)!
		assert probe.urls == ['https://poster-owner.example/base/first-${index}.png']
		attribute := element.get_attribute_node_ns(none, 'poster') or { panic('Missing native poster Attr') }
		assert (model.natural_element_size() or { panic('Missing native poster size') }) == html.VideoDimensions{17, 9}
		assert model.poster_frame() != none && model.current_representation() == .poster_frame
		assert runtime.evaluate_host('mvplaVideos[${index}].setAttribute("poster","next-${index}.png?raw=%20#frame");0')! == '0'
		mvpla_flush(document, runtime)!
		assert probe.urls.len == 2 && probe.urls[1] == 'https://poster-owner.example/base/next-${index}.png?raw=%20#frame'
		assert voidptr(element.get_attribute_node_ns(none, 'poster') or { panic('Lost native poster Attr') }) == voidptr(attribute)
		assert attribute.value() == 'next-${index}.png?raw=%20#frame'
		assert runtime.evaluate_host('mvplaVideos[${index}].removeAttribute("poster");0')! == '0'
		mvpla_flush(document, runtime)!
		assert model.poster_frame() == none && model.natural_element_size() == none
		assert attribute.owner_element() == none && probe.urls.len == 2
		assert runtime.evaluate_host('mvplaVideos[${index}].setAttribute("poster","");0')! == '0'
		mvpla_flush(document, runtime)!
		assert model.poster_frame() == none && probe.urls.len == 2
		assert voidptr(html.html_video_element_model_for_dom_element(video_owner)) == voidptr(model)
		assert model.media.paused() && model.media.current_src() == ''
		assert model.media.network_state() == .empty && model.media.ready_state() == .have_nothing
		for name in ['loadstart', 'play', 'playing', 'pause', 'error', 'resize'] {
			assert model.media.event_count(name) == 0
		}
	}
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0 && runtime.libjs_vm().interpreter_stack().depth() == 0
}
