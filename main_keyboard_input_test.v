module main

import dom
import gg
import html
import page
import time

const keyboard_input_test_markup = '<!doctype html><style>
html,body { margin:0 } body { height:2000px }
#search { margin:20px; width:300px }
#search input { appearance:none; box-sizing:border-box; width:100%; padding:6px; font:13px Arial }
</style><form id="search" action="/search"><input id="query" type="text" name="q" placeholder="search" autocomplete="off"></form>
<textarea id="multiline"></textarea><input id="readonly" readonly value="fixed"><input id="disabled" disabled value="fixed">'

fn keyboard_input_test_app() (&BrowserApp, &html.HTMLInputElementModel) {
	mut owner := page.Page.create(1) or { panic(err) }
	document := parse_browser_navigation_document_for_page_with_response_time(keyboard_input_test_markup, dom.URL{
		value: 'https://old.reddit.com/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	owner.set_local_root_navigable(document.navigable() or { panic('missing navigable') }) or {
		panic(err)
	}
	mut app := &BrowserApp{
		page_model:      owner
		document:        document
		address:         'https://old.reddit.com/'
		viewport_width:  640
		viewport_height: 480
	}
	app.relayout(640, 480 + app.chrome_height())
	query := document.get_element_by_id('query') or { panic('missing search field') }
	model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(query) })
	return app, model
}

fn keyboard_input_test_type(mut app BrowserApp, text string) {
	for code in text.runes() {
		app.handle_character(u32(code))
	}
}

fn test_native_page_search_accepts_typing_after_pointer_focus_with_native_address_bar() {
	mut app, model := keyboard_input_test_app()
	defer { app.document.finalize() }
	// Exercise the same hit/focus and shell callbacks as a native document click.
	app.native_address_bar = true
	app.handle_event(&gg.Event{
		typ:          .mouse_down
		mouse_x:      35
		mouse_y:      30 + app.page_top()
		mouse_button: .left
	})
	app.handle_click(35, 30 + app.page_top())
	app.handle_event(&gg.Event{
		typ:          .mouse_up
		mouse_x:      35
		mouse_y:      30 + app.page_top()
		mouse_button: .left
	})
	assert app.document.active_input_events_target(none) != none
	keyboard_input_test_type(mut app, 'reddit search 🌍')
	assert model.value() == 'reddit search 🌍'
	assert model.text_control.selection_start() == 16
	assert app.address == 'https://old.reddit.com/'
	assert app.paint_commands.any(it.kind == 'draw_text' && it.text.contains('reddit'))
	assert !app.paint_commands.any(it.kind == 'draw_text' && it.text == 'search')
}

fn test_native_page_search_editing_keys_replace_selection_delete_and_undo_without_scrolling() {
	mut app, mut model := keyboard_input_test_app()
	defer { app.document.finalize() }
	dom.run_focusing_steps_for_node(model.control.element.as_node(), none, .click)
	keyboard_input_test_type(mut app, 'abcd')
	app.handle_key(.left, unsafe { gg.Modifier(0) })
	app.handle_key(.backspace, unsafe { gg.Modifier(0) })
	assert model.value() == 'abd'
	app.handle_key(.delete, unsafe { gg.Modifier(0) })
	assert model.value() == 'ab'
	app.handle_key(.home, unsafe { gg.Modifier(0) })
	app.handle_key(.right, .shift)
	keyboard_input_test_type(mut app, 'Z')
	assert model.value() == 'Zb'
	control := $if macos { gg.Modifier.super } $else { gg.Modifier.ctrl }
	app.handle_key(.a, control)
	keyboard_input_test_type(mut app, 'query')
	assert model.value() == 'query'
	app.handle_key(.z, control)
	assert model.value() == 'Zb'
	app.handle_key(.z, control | .shift)
	assert model.value() == 'query'
	app.handle_key(.end, unsafe { gg.Modifier(0) })
	app.handle_key(.apostrophe, unsafe { gg.Modifier(0) })
	app.handle_character(u32(`'`))
	app.handle_key(.period, unsafe { gg.Modifier(0) })
	app.handle_character(u32(`.`))
	assert model.value() == "query'."
	app.handle_key(.down, unsafe { gg.Modifier(0) })
	assert app.scroll_y == 0
}

fn test_native_page_typing_respects_readonly_disabled_and_address_focus() {
	mut app, model := keyboard_input_test_app()
	defer { app.document.finalize() }
	for id in ['readonly', 'disabled'] {
		element := app.document.get_element_by_id(id) or { panic('missing control') }
		control := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
		mut document := unsafe { &dom.Document(app.document) }
		document.set_focused_area(element.as_node())
		keyboard_input_test_type(mut app, 'ignored')
		app.handle_key(.backspace, unsafe { gg.Modifier(0) })
		assert control.value() == 'fixed'
	}
	dom.run_focusing_steps_for_node(model.control.element.as_node(), none, .click)
	app.focus_address_bar()
	keyboard_input_test_type(mut app, 'address')
	assert app.address == 'address'
	assert model.value() == ''
	app.blur_address_bar()
	app.platform_pointer_modifiers = dom.modifier_super
	keyboard_input_test_type(mut app, 'v')
	assert model.value() == ''
	app.platform_pointer_modifiers = dom.modifier_ctrl | dom.modifier_alt
	keyboard_input_test_type(mut app, '€')
	assert model.value() == '€'
}

fn test_native_page_textarea_accepts_unicode_and_return() {
	mut app, _ := keyboard_input_test_app()
	defer { app.document.finalize() }
	element := app.document.get_element_by_id('multiline') or { panic('missing textarea') }
	model :=
		html.html_text_area_element_model_for_dom_element(unsafe { &dom.HTMLTextAreaElement(element) })
	dom.run_focusing_steps_for_node(element.as_node(), none, .click)
	keyboard_input_test_type(mut app, 'Привет')
	app.handle_key(.enter, unsafe { gg.Modifier(0) })
	keyboard_input_test_type(mut app, '🌍')
	assert model.value() == 'Привет\n🌍'
}
