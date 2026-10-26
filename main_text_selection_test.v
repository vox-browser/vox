module main

import dom
import gg
import html
import page
import sokol.sapp
import time

struct TextSelectionClicks {
mut:
	details []int
	doubles int
}

fn text_selection_app(markup string) &BrowserApp {
	mut owner := page.Page.create(1) or { panic(err) }
	document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><style>html,body,p{margin:0} body{font:20px monospace;line-height:24px} input,textarea{font:20px monospace}</style>' + markup,
		dom.URL{ value: 'https://example.com/' }, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	owner.set_local_root_navigable(document.navigable() or { panic('missing navigable') }) or { panic(err) }
	mut app := &BrowserApp{ page_model: owner, document: document, viewport_width: 640, viewport_height: 480 }
	app.relayout(640, 480 + app.chrome_height())
	return app
}

fn text_selection_point(app &BrowserApp, text string, offset int) page.PixelPoint {
	paintable := app.document.paintable_box() or { panic('missing paintable') }
	for y := 5; y < 240; y += 10 {
		for x := 2; x < 620; x += 2 {
			hit := paintable.hit_test(x, y, .text_cursor) or { continue }
			if hit.node == unsafe { nil } || !hit.node.is_text() || hit.index_in_node != offset {
				continue
			}
			if unsafe { &dom.Text(hit.node) }.data() == text {
				return page.PixelPoint{ x: x, y: y }
			}
		}
	}
	panic('no hit for ${text} at ${offset}')
}

fn text_selection_click(mut app BrowserApp, point page.PixelPoint) {
	for typ in [sapp.EventType.mouse_down, .mouse_up] {
		app.handle_event(&gg.Event{ typ: typ, mouse_x: f32(point.x), mouse_y: f32(point.y + app.page_top()), mouse_button: .left })
		if typ == .mouse_down {
			app.handle_click(f32(point.x), f32(point.y + app.page_top()))
		}
	}
	app.begin_frame_preparation()
	app.finish_frame_preparation()
}

fn text_selection_string(app &BrowserApp) string {
	selection := app.document.get_selection() or { panic('missing selection') }
	return (selection.range() or { return '' }).to_string()
}

fn test_native_double_click_selects_word_and_triple_click_selects_paragraph() {
	mut app := text_selection_app('<p>hello <b>brave</b> world</p><p>next paragraph</p>')
	defer { app.document.finalize() }
	clicks := &TextSelectionClicks{}
	mut target := unsafe { &dom.EventTarget(app.document) }
	for name in ['click', 'dblclick'] {
		target.add_event_listener_without_options(name, dom.IDLEventListener.create(&dom.CallbackType{
			handle_event: fn [clicks] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
				mut observed := unsafe { &TextSelectionClicks(clicks) }
				if event.type_ == 'click' {
					observed.details << unsafe { &dom.MouseEvent(event) }.detail()
				} else {
					observed.doubles++
				}
				return dom.js_undefined()
			}
		}))
	}
	point := text_selection_point(app, 'brave', 2)
	text_selection_click(mut app, point)
	assert text_selection_string(app) == ''
	text_selection_click(mut app, point)
	assert app.pointer_clicks.count == 2
	assert text_selection_string(app) == 'brave'
	assert app.paint_commands.any(it.kind == 'fill_rect' && it.force_dark_role == .selection)
	text_selection_click(mut app, point)
	assert app.pointer_clicks.count == 3
	assert text_selection_string(app) == 'hello brave world'
	text_selection_click(mut app, point)
	assert app.pointer_clicks.count == 1
	assert text_selection_string(app) == ''
	assert !app.paint_commands.any(it.kind == 'fill_rect' && it.force_dark_role == .selection)
	assert clicks.details == [1, 2, 3, 1]
	assert clicks.doubles == 1
}

fn test_native_triple_click_stops_at_nested_breaks_and_includes_wrapped_lines() {
	mut app := text_selection_app('<p style="width:170px">before<span><br><i>several wrapped words</i><br></span>after</p>')
	defer { app.document.finalize() }
	point := text_selection_point(app, 'several wrapped words', 3)
	for _ in 0 .. 3 { text_selection_click(mut app, point) }
	assert text_selection_string(app) == 'several wrapped words'
}

fn test_native_triple_click_selects_editable_paragraph_with_inline_children() {
	mut app := text_selection_app('<div contenteditable><p>hello <b>brave</b> world</p><p>next paragraph</p></div>')
	defer { app.document.finalize() }
	point := text_selection_point(app, 'brave', 2)
	for _ in 0 .. 3 { text_selection_click(mut app, point) }
	assert text_selection_string(app) == 'hello brave world'
}

fn test_ui2_word_selection_converts_unicode_columns_to_dom_utf16() {
	assert browser_text_word_range('😀 привет мир', 6) == page.SelectionRange{ start: 3, end: 9 }
	assert browser_text_word_range('😀 cafe\u0301!', 6) == page.SelectionRange{ start: 3, end: 8 }
	assert browser_text_word_range('😀!', 0) == page.SelectionRange{ start: 0, end: 2 }
	assert browser_text_word_range('hello', 5) == page.SelectionRange{ start: 0, end: 5 }
	assert browser_text_word_range('a  b', 1) == page.SelectionRange{ start: 1, end: 3 }
	assert browser_text_word_range('', 0) == page.SelectionRange{}
	mut app := text_selection_app('<p>😀 привет мир</p>')
	defer { app.document.finalize() }
	point := text_selection_point(app, '😀 привет мир', 6)
	text_selection_click(mut app, point)
	text_selection_click(mut app, point)
	assert text_selection_string(app) == 'привет'
}

fn test_click_sequence_resets_after_timeout_distance_button_or_document_change() {
	mut first := dom.Document.create_for_fragment_parsing()
	mut second := dom.Document.create_for_fragment_parsing()
	defer {
		first.finalize()
		second.finalize()
	}
	mut clicks := BrowserPointerClicks{}
	assert clicks.press(first, 0, 10, 10, 1000) == 1
	assert clicks.press(first, 0, 12, 10, 1100) == 2
	assert clicks.press(first, 0, 12, 10, 1200) == 3
	assert clicks.press(first, 0, 12, 10, 1300) == 1
	assert clicks.press(first, 0, 12, 10, 2000) == 1
	assert clicks.press(first, 0, 30, 10, 2100) == 1
	assert clicks.press(first, 2, 30, 10, 2200) == 1
	assert clicks.press(first, 0, 30, 10, 2300) == 1
	assert clicks.press(second, 0, 30, 10, 2400) == 1
	assert clicks.press(second, 0, 30, 10, 2300) == 1
}

fn test_native_multi_click_selects_text_control_word_and_current_line() {
	mut app := text_selection_app('<input id="input" style="display:block;width:400px" value="hello brave world"><textarea id="area" style="display:block;width:400px">first line\nsecond line</textarea>')
	defer { app.document.finalize() }
	input := app.document.get_element_by_id('input') or { panic('missing input') }
	model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(input) })
	point := text_selection_point(app, 'hello brave world', 8)
	text_selection_click(mut app, point)
	text_selection_click(mut app, point)
	assert model.text_control.selection_start() == 6
	assert model.text_control.selection_end() == 11
	text_selection_click(mut app, point)
	assert model.text_control.selection_start() == 0
	assert model.text_control.selection_end() == 17
	area := app.document.get_element_by_id('area') or { panic('missing textarea') }
	area_model := html.html_text_area_element_model_for_dom_element(unsafe { &dom.HTMLTextAreaElement(area) })
	line_point := text_selection_point(app, 'first line\nsecond line', 14)
	for _ in 0 .. 3 { text_selection_click(mut app, line_point) }
	assert area_model.text.selection_start() == 11
	assert area_model.text.selection_end() == 22
}

fn test_cancelled_presses_and_user_select_none_preserve_selection() {
	for cancellation in ['', 'pointerdown', 'mousedown'] {
		mut app := text_selection_app('<p id="text" style="' + if cancellation == '' {
			'user-select:none'
		} else {
			''
		} + '">hello world</p>')
		defer { app.document.finalize() }
		element := app.document.get_element_by_id('text') or { panic('missing text') }
		node := element.as_node().first_child() or { panic('missing text node') }
		mut selection := app.document.get_selection() or { panic('missing selection') }
		selection.set_base_and_extent(node, 0, node, 5) or { panic(err) }
		if cancellation != '' {
			mut target := unsafe { &dom.EventTarget(element) }
			target.add_event_listener_without_options(cancellation, dom.IDLEventListener.create(&dom.CallbackType{
				handle_event: fn (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
					mut mutable_event := unsafe { &dom.Event(event) }
					mutable_event.prevent_default()
					return dom.js_undefined()
				}
			}))
		}
		point := text_selection_point(app, 'hello world', 8)
		for _ in 0 .. 3 { text_selection_click(mut app, point) }
		assert text_selection_string(app) == 'hello'
	}
}
