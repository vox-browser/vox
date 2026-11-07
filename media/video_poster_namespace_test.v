module main

import dom
import html
import layout
import page
import time

const native_poster_namespace_small = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='
const native_poster_namespace_green = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAD0lEQVR4nGNgaGBAIOI4ANA0CAF5jtVRAAAAAElFTkSuQmCC'

fn native_poster_namespace_document() !&dom.Document {
	owner := page.Page.create(1)!
	return parse_browser_navigation_document_for_page_with_response_time(
		'<!doctype html><video id="video" preload="none"></video><svg><video id="foreign-video"></video></svg>',
		dom.URL{value: 'https://native-poster-namespace.example/base/page.html'}, none, none,
		unsafe { &dom.Page(owner) }, time.sys_mono_now())
}

fn native_poster_namespace_assert_idle(model &html.HTMLVideoElementModel, document &dom.Document) {
	assert model.media.paused() && model.media.current_src() == ''
	assert model.media.network_state() == .empty && model.media.ready_state() == .have_nothing
	assert !document.anything_is_delaying_the_load_event()
	for name in ['loadstart', 'play', 'playing', 'error', 'resize'] {
		assert model.media.event_count(name) == 0
	}
}

fn test_native_poster_installer_decodes_the_null_namespace_value_in_either_attribute_order() {
	$if !darwin { return }
	for foreign_first in [true, false] {
		mut document := native_poster_namespace_document()!
		defer { document.finalize() }
		mut element := document.get_element_by_id('video') or { panic('missing native poster owner') }
		owner := unsafe { &dom.HTMLVideoElement(element) }
		if !foreign_first { element.set_attribute_value_ns('poster', native_poster_namespace_green, none, none) }
		element.set_attribute_ns_for_bindings('urn:native-poster', 'poster', native_poster_namespace_small)!
		if foreign_first { element.set_attribute_value_ns('poster', native_poster_namespace_green, none, none) }
		attribute := element.get_attribute_node_ns(none, 'poster') or { panic('missing actual poster Attr') }
		assert owner.video_element_model_ == unsafe { nil }
		assert element.get_attribute('poster')? == if foreign_first { native_poster_namespace_small } else { native_poster_namespace_green }
		install_video_poster_fetch_hooks(document)
		model := html.html_video_element_model_for_dom_element(owner)
		bitmap := model.poster_frame() or { panic('missing decoded null-namespace poster') }
		assert bitmap.width == 4 && bitmap.height == 4 && bitmap.pitch == 16
		assert bitmap.native_rows_are_top_down && bitmap.data.len == 64
		for pixel in 0 .. 16 { assert bitmap.data[pixel * 4..pixel * 4 + 4] == [u8(0), 128, 0, 255] }
		assert model.natural_element_size()? == html.VideoDimensions{4, 4}
		assert voidptr(element.get_attribute_node_ns(none, 'poster')?) == voidptr(attribute)
		assert attribute.value() == native_poster_namespace_green
		result := layout.run_document_layout(document, 320, 200) or { panic('missing native poster layout') }
		commands := result.paint_tree.paint_commands().filter(it.kind == 'draw_video')
		assert commands.len == 1 && commands[0].video_bitmap?.data == bitmap.data
		foreign := document.get_element_by_id('foreign-video') or { panic('missing SVG video') }
		assert html.html_media_element_for_dom_element(foreign) == none
		native_poster_namespace_assert_idle(model, document)
	}
}

fn test_native_poster_installer_ignores_foreign_only_and_uppercase_poster_attributes() {
	$if !darwin { return }
	mut document := native_poster_namespace_document()!
	defer { document.finalize() }
	mut element := document.get_element_by_id('video') or { panic('missing foreign-only poster owner') }
	element.set_attribute_ns_for_bindings('urn:native-poster', 'poster', native_poster_namespace_small)!
	element.set_attribute_ns_for_bindings(none, 'POSTER', native_poster_namespace_green)!
	element.set_attribute_ns_for_bindings('urn:native-prefixed', 'p:poster', native_poster_namespace_green)!
	assert element.get_attribute_ns(none, 'poster') == none
	install_video_poster_fetch_hooks(document)
	mut model := html.html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
	assert model.poster_frame() == none && model.natural_element_size() == none
	assert model.current_representation() == .transparent_black
	// The installed real decoder remains available for the first actual poster.
	element.set_attribute_value_ns('poster', native_poster_namespace_green, none, none)
	assert model.poster_frame()?.width == 4
	element.remove_attribute_ns(none, 'poster')
	assert model.poster_frame() == none && model.natural_element_size() == none
	model.determine_element_poster_frame()
	assert model.poster_frame() == none
	native_poster_namespace_assert_idle(model, document)
}

fn test_native_poster_empty_and_invalid_actual_values_do_not_fall_back_to_foreign_pixels() {
	$if !darwin { return }
	for value in ['', 'http://[invalid'] {
		mut document := native_poster_namespace_document()!
		defer { document.finalize() }
		mut element := document.get_element_by_id('video') or { panic('missing clearing poster owner') }
		element.set_attribute_ns_for_bindings('urn:native-poster', 'poster', native_poster_namespace_small)!
		element.set_attribute_value_ns('poster', value, none, none)
		install_video_poster_fetch_hooks(document)
		model := html.html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
		assert model.poster_frame() == none && model.natural_element_size() == none
		assert element.get_attribute_ns(none, 'poster')? == value
		element.set_attribute_value_ns('poster', native_poster_namespace_green, none, none)
		frame := model.poster_frame() or { panic('missing recovered real poster') }
		assert frame.width == 4 && frame.height == 4
		element.set_attribute_ns_for_bindings('urn:native-poster', 'poster', 'data:image/png,invalid')!
		assert voidptr(model.poster_frame()?) == voidptr(frame)
		element.set_attribute_value_ns('poster', native_poster_namespace_small, none, none)
		assert model.poster_frame()?.width == 1 && model.natural_element_size()? == html.VideoDimensions{1, 1}
		native_poster_namespace_assert_idle(model, document)
	}
}
