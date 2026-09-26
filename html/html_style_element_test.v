@[has_globals]
module html

import css
import dom

__global (
	style_element_load_event_count = 0
)

fn record_style_element_load_event(event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
	assert event.type_name() == 'load'
	assert !event.bubbles()
	style_element_load_event_count++
	return dom.js_undefined()
}

fn style_element_test_document_sheets(document &dom.Document) []&css.CSSStyleSheet {
	mut scope := css.style_scope_for_dom_node(document.as_node())
	return scope.style_sheet_list().sheets
}

fn style_element_test_create(mut document dom.Document, css_text string) &dom.Element {
	mut style := document.create_element_ns('http://www.w3.org/1999/xhtml', 'style') or { panic(err) }
	mut style_node := unsafe { &dom.Node(style) }
	style_node.set_text_content(css_text) or { panic(err) }
	return style
}

fn test_parser_created_style_element_creates_its_sheet_when_popped() {
	document := parse_document('<!doctype html><head><style id="style" media="screen" title="main">p { color: green }</style></head><p>text</p>')
	style := document.get_element_by_id('style') or { panic('missing style') }
	sheet := css.style_element_sheet(style) or { panic('style element has no sheet') }
	owner := sheet.base.owner_node or { panic('sheet has no owner node') }
	assert voidptr(owner) == voidptr(style)
	assert sheet.base.title == 'main'
	assert sheet.base.media.media_text() == 'screen'
	assert sheet.css_rules().length() == 1
	sheets := style_element_test_document_sheets(document)
	assert sheets.len == 1
	assert voidptr(sheets[0]) == voidptr(sheet)
}

fn test_style_block_waits_for_parser_pop_before_updating() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut html_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic(err) }
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(html_element.as_node()) or { panic(err) }
	mut style := document.create_element_ns('http://www.w3.org/1999/xhtml', 'style') or { panic(err) }
	mut base := style.style_element_base() or { panic('missing style element base') }
	base.set_parser_document(document)
	mut html_node := unsafe { &dom.Node(html_element) }
	html_node.append_child(style.as_node()) or { panic(err) }
	mut style_node := unsafe { &dom.Node(style) }
	style_node.append_child(document.create_text_node('p { color: red }').as_node()) or {
		panic(err)
	}
	assert base.sheet() == unsafe { nil }

	base.did_pop_off_parser_stack_of_open_elements()
	sheet := css.style_element_sheet(style) or { panic('style element has no sheet after pop') }
	assert sheet.css_rules().length() == 1
}

fn test_dynamic_style_element_updates_replace_and_remove_its_sheet() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut html_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic(err) }
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(html_element.as_node()) or { panic(err) }
	mut style := style_element_test_create(mut document, 'p { color: red }')
	assert css.style_element_sheet(style) == none

	mut html_node := unsafe { &dom.Node(html_element) }
	html_node.append_child(style.as_node()) or { panic(err) }
	first := css.style_element_sheet(style) or { panic('inserted style element has no sheet') }
	assert style_element_test_document_sheets(document).len == 1

	mut style_node := unsafe { &dom.Node(style) }
	style_node.set_text_content('p { color: red } div { color: blue }') or { panic(err) }
	second := css.style_element_sheet(style) or { panic('changed style element has no sheet') }
	assert voidptr(second) != voidptr(first)
	assert second.css_rules().length() == 2
	assert first.base.owner_node == none
	sheets := style_element_test_document_sheets(document)
	assert sheets.len == 1
	assert voidptr(sheets[0]) == voidptr(second)

	style.set_attribute_value('type', 'text/less')
	assert css.style_element_sheet(style) == none
	assert style_element_test_document_sheets(document).len == 0
	style.set_attribute_value('type', 'TEXT/CSS')
	assert css.style_element_sheet(style) != none

	html_node.remove_child(style.as_node()) or { panic(err) }
	assert css.style_element_sheet(style) == none
	assert style_element_test_document_sheets(document).len == 0
}

fn test_style_element_media_title_and_disabled_state_live_on_its_sheet() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut html_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic(err) }
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(html_element.as_node()) or { panic(err) }
	mut html_node := unsafe { &dom.Node(html_element) }

	mut preferred := style_element_test_create(mut document, 'p { color: green }')
	preferred.set_attribute_value('title', 'preferred')
	mut other := style_element_test_create(mut document, 'p { color: red }')
	other.set_attribute_value('title', 'other')
	html_node.append_child(preferred.as_node()) or { panic(err) }
	html_node.append_child(other.as_node()) or { panic(err) }
	mut preferred_base := preferred.style_element_base() or { panic('missing base') }
	other_base := other.style_element_base() or { panic('missing base') }
	assert !preferred_base.disabled()
	assert other_base.disabled()

	preferred.set_attribute_value('media', 'print')
	preferred_sheet := css.style_element_sheet(preferred) or { panic('missing sheet') }
	assert preferred_sheet.base.media.media_text() == 'print'

	preferred_base.set_disabled(true)
	assert preferred_base.disabled()
	assert preferred_sheet.base.disabled
	preferred_base.set_disabled(false)
	assert !preferred_base.disabled()
}

fn test_style_element_sheets_follow_tree_order_and_shadow_scopes() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut html_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic(err) }
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(html_element.as_node()) or { panic(err) }
	mut html_node := unsafe { &dom.Node(html_element) }

	mut later := style_element_test_create(mut document, 'p { color: red }')
	html_node.append_child(later.as_node()) or { panic(err) }
	mut earlier := style_element_test_create(mut document, 'p { color: green }')
	html_node.insert_before(earlier.as_node(), later.as_node(), false)
	sheets := style_element_test_document_sheets(document)
	assert sheets.len == 2
	assert voidptr(sheets[0]) == voidptr(css.style_element_sheet(earlier) or { panic('earlier') })
	assert voidptr(sheets[1]) == voidptr(css.style_element_sheet(later) or { panic('later') })

	mut host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	html_node.append_child(host.as_node()) or { panic(err) }
	mut shadow_root := host.attach_shadow(dom.ShadowRootInit{
		mode: .open
	}) or { panic(err) }
	mut shadow_style := style_element_test_create(mut document, 'p { color: blue }')
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	shadow_node.append_child(shadow_style.as_node()) or { panic(err) }
	shadow_sheet := css.style_element_sheet(shadow_style) or { panic('shadow style has no sheet') }
	mut shadow_scope := css.style_scope_for_dom_node(shadow_node)
	shadow_sheets := shadow_scope.style_sheet_list().sheets
	assert shadow_sheets.len == 1
	assert voidptr(shadow_sheets[0]) == voidptr(shadow_sheet)
	assert style_element_test_document_sheets(document).len == 2
}

fn test_style_element_fires_load_on_an_element_task() {
	style_element_load_event_count = 0
	mut document := dom.Document.create(dom.url_about_blank())
	_ = WindowModel.create_top_level(document, none, 'style-element-test') or { panic(err) }
	mut html_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic(err) }
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(html_element.as_node()) or { panic(err) }
	mut style := style_element_test_create(mut document, 'p { color: green }')
	listener := dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: record_style_element_load_event
	})
	unsafe { &dom.EventTarget(style.as_node()) }.add_event_listener_without_options('load',
		listener)

	mut html_node := unsafe { &dom.Node(html_element) }
	html_node.append_child(style.as_node()) or { panic(err) }
	assert style_element_load_event_count == 0
	mut event_loop := main_thread_event_loop()
	for event_loop.task_queue().has_runnable_tasks() {
		event_loop.process()
	}
	assert style_element_load_event_count == 1

	// A queued completion for a sheet that has since been replaced is ignored.
	mut style_node := unsafe { &dom.Node(style) }
	style_node.set_text_content('p { color: red }') or { panic(err) }
	style_node.set_text_content('p { color: blue }') or { panic(err) }
	for event_loop.task_queue().has_runnable_tasks() {
		event_loop.process()
	}
	assert style_element_load_event_count == 2
	document.finalize()
}
