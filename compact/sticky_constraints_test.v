module main

import dom
import browserjs
import html
import layout

fn test_oversized_sticky_view_rectangles_reduce_the_end_inset() {
	for horizontal in [true, false] {
		direction := if horizontal { 'row' } else { 'column' }
		insets := if horizontal { 'left:20px;right:0' } else { 'top:20px;bottom:0' }
		size := if horizontal { 'width:200px;height:100px' } else { 'width:100px;height:200px' }
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#scroller{width:100px;height:100px;overflow:auto;position:relative;display:flex;flex-direction:${direction}}.padding,#sticky{${size};flex:none}#sticky{position:sticky;${insets}}</style><div id="scroller"><div class="padding"></div><div id="sticky"></div><div class="padding"></div></div>')
		defer { document.finalize() }
		_ = layout.layout_document_typed_in_viewport(document, 800, 600)
		mut runtime := browserjs.Runtime.create()
		defer { runtime.close() }
		mut messages := []string{}
		run_document_javascript(document, 'about:blank', [], runtime, mut messages)
		assert messages == []string{}
		mut scroller := document.get_element_by_id('scroller') or { panic('scroller') }
		sticky := document.get_element_by_id('sticky') or { panic('sticky') }
		for index, scroll in [0, 160, 220, 500] {
			if horizontal {
				scroller.set_scroll_left(scroll)
			} else {
				scroller.set_scroll_top(scroll)
			}
			host := unsafe { &dom.HTMLElement(sticky) }
			actual := if horizontal {
				html.html_element_offset_left(host)
			} else {
				html.html_element_offset_top(host)
			}
			assert actual == [20, 180, 240, 400][index], '${direction} scroll ${scroll}: ${actual}'
		}
	}
}

fn test_sticky_clamping_retains_the_position_box_end_margin() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#scroller{position:relative;width:100px;height:200px;overflow:hidden}#contents{height:500px}#before,#filler{height:100px}#container{height:300px}#sticky{position:sticky;top:50px;width:100%;height:100px;margin:15px}</style><div id="scroller"><div id="contents"><div id="before"></div><div id="container"><div id="filler"></div><div id="sticky"></div></div></div></div>')
	defer { document.finalize() }
	_ = layout.layout_document_typed_in_viewport(document, 800, 600)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [], runtime, mut messages)
	assert messages == []string{}
	mut scroller := document.get_element_by_id('scroller') or { panic('scroller') }
	scroller.set_scroll_top(300)
	sticky := document.get_element_by_id('sticky') or { panic('sticky') }
	assert html.html_element_offset_top(unsafe { &dom.HTMLElement(sticky) }) == 285
}
