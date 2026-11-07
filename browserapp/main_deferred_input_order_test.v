module main

import dom
import gg
import html
import page

fn deferred_order_app() &BrowserApp {
	mut owner := page.Page.create(1) or { panic(err) }
	mut app := &BrowserApp{page_model: owner, viewport_width: 320, viewport_height: 200}
	app.install_loaded_page(LoadedPage{url: 'https://input-order.test/', content_type: 'text/html',
		markup: '<!doctype html><textarea id="field"></textarea>'}, false)
	field := app.document.get_element_by_id('field') or { panic('field') }
	dom.run_focusing_steps_for_node(field.as_node(), none, .click)
	app.ctx = &gg.Context{}
	return app
}

fn deferred_order_character(mut app BrowserApp, code u32) {
	app.handle_event(&gg.Event{typ: .char, char_code: code})
	app.handle_character(code)
}

fn deferred_order_value(app &BrowserApp) string {
	field := app.document.get_element_by_id('field') or { panic('field') }
	return html.html_text_area_element_model_for_dom_element(unsafe { &dom.HTMLTextAreaElement(field) }).value()
}

fn test_new_characters_cannot_overtake_text_queued_during_document_work() {
	mut app := deferred_order_app()
	mut document := app.document
	defer { document.finalize() }
	mut scope := app.begin_navigation_work()
	deferred_order_character(mut app, u32(`A`))
	scope.finish()
	deferred_order_character(mut app, u32(`B`))
	app.ctx = unsafe { nil }
	app.poll_deferred_page_input()
	assert deferred_order_value(app) == 'AB'
	assert app.deferred_page_input.len == 0 && !app.replaying_deferred_page_input
}

fn test_editing_keys_cannot_overtake_queued_text() {
	mut app := deferred_order_app()
	mut document := app.document
	defer { document.finalize() }
	mut scope := app.begin_navigation_work()
	deferred_order_character(mut app, u32(`A`))
	scope.finish()
	app.handle_event(&gg.Event{typ: .key_down, key_code: .backspace})
	app.handle_key(.backspace, unsafe { gg.Modifier(0) })
	app.ctx = unsafe { nil }
	app.poll_deferred_page_input()
	assert deferred_order_value(app) == ''
}

fn test_mouse_release_waits_for_a_queued_press() {
	mut app := deferred_order_app()
	mut document := app.document
	defer { document.finalize() }
	mut scope := app.begin_navigation_work()
	app.handle_event(&gg.Event{typ: .mouse_down, mouse_button: .left, mouse_x: 20, mouse_y: 100})
	scope.finish()
	app.handle_event(&gg.Event{typ: .mouse_up, mouse_button: .left, mouse_x: 20, mouse_y: 100})
	assert app.deferred_page_input.len == 2
	assert app.deferred_page_input[0].event.typ == .mouse_down
	assert app.deferred_page_input[1].event.typ == .mouse_up
	app.ctx = unsafe { nil }
	app.poll_deferred_page_input()
	assert app.deferred_page_input.len == 0 && app.platform_pointer_buttons == 0
}
