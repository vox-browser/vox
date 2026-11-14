module main

import dom
import gg
import html
import layout
import page
import time

const text_control_relayout_markup = '<!doctype html><style>
html,body { margin:0 } body { font:14px Arial }
.grid { display:grid; grid-template-columns:1fr auto; gap:4px; padding:3px }
.flex { display:flex; align-items:center; gap:6px }
#area { width:240px; height:40px; font:13px Arial }
#line { width:200px; font:13px Arial }
</style><main class="grid"><section class="grid"><div class="flex"><span>Before</span>
<textarea id="area"></textarea><button>Send</button></div><p>Sibling paragraph text</p></section>
<aside>aside</aside></main><div class="flex"><input id="query" type="text"><input id="line" type="text"><span id="after">after</span></div>'

fn text_control_relayout_app(markup string) (&BrowserApp, &html.HTMLInputElementModel) {
	mut owner := page.Page.create(1) or { panic(err) }
	document := parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{
		value: 'https://example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	owner.set_local_root_navigable(document.navigable() or { panic('missing navigable') }) or {
		panic(err)
	}
	mut app := &BrowserApp{
		page_model:      owner
		document:        document
		address:         'https://example.test/'
		viewport_width:  640
		viewport_height: 480
	}
	app.relayout(640, 480 + app.chrome_height())
	query := document.get_element_by_id('query') or { panic('missing query field') }
	return app, html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(query) })
}

fn text_control_relayout_display_list(mut document dom.Document) string {
	return (document.record_display_list() or { panic('missing display list') }).dump()
}

// Lay out after the edit, then require the same painted result from a
// complete rebuild of the layout tree.
fn text_control_relayout_check(mut app BrowserApp) {
	mut document := unsafe { &dom.Document(app.document) }
	document.update_layout(.debugging)
	painted := text_control_relayout_display_list(mut document)
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert text_control_relayout_display_list(mut document) == painted
}

fn text_control_relayout_focus(mut app BrowserApp, id string) {
	element := app.document.get_element_by_id(id) or { panic('missing ${id}') }
	dom.run_focusing_steps_for_node(element.as_node(), none, .click)
	app.begin_frame_preparation()
	app.finish_frame_preparation()
}

fn test_typing_into_a_nested_textarea_relays_out_only_the_control() {
	mut app, _ := text_control_relayout_app(text_control_relayout_markup)
	defer { app.document.finalize() }
	text_control_relayout_focus(mut app, 'area')
	// The first character turns the empty editor text into rendered text,
	// which rebuilds that part of the layout tree.
	app.handle_character(u32(`>`))
	text_control_relayout_check(mut app)
	after := app.document.get_element_by_id('after') or { panic('missing after') }
	before_rect := after.get_bounding_client_rect()
	for code in 'hello text'.runes() {
		passes := layout.text_control_relayout_pass_count()
		app.handle_character(u32(code))
		mut document := unsafe { &dom.Document(app.document) }
		document.update_layout(.debugging)
		assert layout.text_control_relayout_pass_count() == passes + 1
		assert after.get_bounding_client_rect() == before_rect
		text_control_relayout_check(mut app)
	}
	// A fallback-font glyph can change the editor's line height; the control
	// then lays out its ancestors again.
	app.handle_character(u32(`🌍`))
	text_control_relayout_check(mut app)
	element := app.document.get_element_by_id('area') or { panic('missing area') }
	model := html.html_text_area_element_model_for_dom_element(unsafe { &dom.HTMLTextAreaElement(element) })
	assert model.value() == '>hello text🌍'
}

fn test_typing_into_a_text_input_relays_out_only_the_control() {
	mut app, model := text_control_relayout_app(text_control_relayout_markup)
	defer { app.document.finalize() }
	text_control_relayout_focus(mut app, 'line')
	app.handle_character(u32(`>`))
	text_control_relayout_check(mut app)
	for code in 'query that overflows the visible input width'.runes() {
		passes := layout.text_control_relayout_pass_count()
		app.handle_character(u32(code))
		mut document := unsafe { &dom.Document(app.document) }
		document.update_layout(.debugging)
		assert layout.text_control_relayout_pass_count() == passes + 1
	}
	assert model.value() == ''
	text_control_relayout_check(mut app)
	line := app.document.get_element_by_id('line') or { panic('missing line') }
	line_model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(line) })
	assert line_model.value() == '>query that overflows the visible input width'
}

// An automatically sized textarea grows with its lines; a baseline-aligned
// one can move its baseline when it stops being empty. Both must lay out
// their ancestors again with the same result as a complete pass.
fn test_growing_or_baseline_aligned_textareas_keep_complete_layout_results() {
	markup := '<!doctype html><style>html,body { margin:0 } body { font:14px Arial }
		.row { display:flex; align-items:baseline; gap:4px }
		textarea { width:120px; font:13px Arial; field-sizing:content; min-height:0 }</style>
		<div class="row"><span>label</span><textarea id="area"></textarea><span id="after">after</span></div>
		<input id="query" type="text">
		<p>below</p>'
	mut app, _ := text_control_relayout_app(markup)
	defer { app.document.finalize() }
	text_control_relayout_focus(mut app, 'area')
	for code in 'grow'.runes() {
		app.handle_character(u32(code))
		text_control_relayout_check(mut app)
	}
	for _ in 0 .. 4 {
		app.handle_key(.enter, unsafe { gg.Modifier(0) })
		text_control_relayout_check(mut app)
		app.handle_character(u32(`x`))
		text_control_relayout_check(mut app)
	}
}

fn test_other_layout_changes_between_keys_use_a_complete_pass() {
	mut app, _ := text_control_relayout_app(text_control_relayout_markup)
	defer { app.document.finalize() }
	text_control_relayout_focus(mut app, 'area')
	app.handle_character(u32(`a`))
	mut after := app.document.get_element_by_id('after') or { panic('missing after') }
	after.set_attribute_value('style', 'display:inline-block; width:77px')
	passes := layout.text_control_relayout_pass_count()
	mut document := unsafe { &dom.Document(app.document) }
	document.update_layout(.debugging)
	assert layout.text_control_relayout_pass_count() == passes
	assert after.get_bounding_client_rect().width == 77
	text_control_relayout_check(mut app)
	// The complete pass records the control again for the next keystroke.
	app.handle_character(u32(`b`))
	document.update_layout(.debugging)
	assert layout.text_control_relayout_pass_count() == passes + 1
	text_control_relayout_check(mut app)
}
