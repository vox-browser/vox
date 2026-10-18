module main

import dom
import gg
import html
import platform

fn (app &BrowserApp) prepare_page_editing_target() ?&dom.InputEventsTarget {
	focused := app.document.focused_area() or { return none }
	if element := focused.as_element() {
		if element.is_html_element() && element.local_name() == 'textarea' {
			mut model :=
				html.html_text_area_element_model_for_dom_element(unsafe { &dom.HTMLTextAreaElement(element) })
			model.create_shadow_tree_if_needed()
		}
	}
	return app.document.active_input_events_target(none)
}

fn (mut app BrowserApp) handle_page_character(code u32) {
	if app.navigation_work_depth > 0 || app.document == unsafe { nil }
		|| !app.document.is_fully_active() {
		return
	}
	mut heap_scope :=
		platform.begin_browser_activity_heap_scope_for_scripting(app.document_scripting_enabled_for_heap())
	defer { heap_scope.finish() }
	mut navigation_work := app.begin_navigation_work()
	defer { navigation_work.finish() }
	target := app.prepare_page_editing_target() or { return }
	target.handle_insert(dom.input_type_insert_text, rune(code).str())
	app.finish_page_editing_input()
}

// Sokol delivers printable text separately through char_fn. Only navigation,
// deletion, Return and editing shortcuts go through the key-down default action.
fn browser_editing_key(key gg.KeyCode) int {
	return match key {
		.backspace { 8 }
		.delete { 46 }
		.enter, .kp_enter { 13 }
		.left { 37 }
		.right { 39 }
		.up { 38 }
		.down { 40 }
		.home { 35 }
		.end { 36 }
		.page_up { 33 }
		.page_down { 34 }
		.a, .c, .v, .x, .y, .z { int(key) }
		else { 0 }
	}
}

fn (mut app BrowserApp) handle_page_editing_key(key gg.KeyCode, modifier gg.Modifier) bool {
	if app.document == unsafe { nil } || app.page_model == unsafe { nil }
		|| !app.document.is_fully_active() {
		return false
	}
	if app.prepare_page_editing_target() == none { return false }
	page_key := browser_editing_key(key)
	if page_key == 0 { return true }
	mut heap_scope :=
		platform.begin_browser_activity_heap_scope_for_scripting(app.document_scripting_enabled_for_heap())
	defer { heap_scope.finish() }
	mut navigation_work := app.begin_navigation_work()
	defer { navigation_work.finish() }
	mut handler := app.page_model.event_handler
	handler.set_document_state(true, app.document.layout_node() != none)
	result := app.page_model.handle_keydown(page_key, browser_pointer_modifiers(u32(modifier)), 0,
		false)
	if result != .accepted { app.finish_page_editing_input() }
	return true
}

fn (mut app BrowserApp) finish_page_editing_input() {
	app.poll_javascript_tasks()
	app.begin_frame_preparation()
	app.finish_frame_preparation()
	request_browser_frame()
}
