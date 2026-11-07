module main

import browserjs
import dom
import html
import layout

fn test_live_canvas_resize_preserves_bitmap_and_dom_owner_after_replay() {
	$if !darwin { return }
	document := html.parse_document('<!doctype html><canvas id="canvas" width="50" height="50"></canvas>')
	layout.run_document_layout(document, 120, 120) or { panic('layout') }
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', ['const context=canvas.getContext("2d");context.fillStyle="red";context.fillRect(0,0,50,50);canvas.width=100;canvas.height=100;context.fillStyle="lime";context.fillRect(0,0,100,100);'], runtime, mut messages)
	element := document.get_element_by_id('canvas') or { panic('canvas') }
	provided := runtime.canvas_elements_for_binding()['__element_3'] or { panic('native canvas') }
	assert voidptr(element) == voidptr(provided)
	assert messages == []
	canvas := unsafe { &dom.HTMLCanvasElement(element) }
	assert html.html_canvas_element_width(canvas) == 100
	bitmap := html.html_canvas_element_surface(canvas) or { panic('bitmap') }
	assert bitmap.width == 100
	assert bitmap.height == 100
	assert bitmap.data[..4] == [u8(0), 255, 0, 255]
}
