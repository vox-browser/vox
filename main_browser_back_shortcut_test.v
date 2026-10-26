module main

import dom
import gg
import html
import page

fn back_shortcut_test_app() &BrowserApp {
	mut app := &BrowserApp{
		page_model:      page.Page.create(1) or { panic(err) }
		viewport_width:  800
		viewport_height: 600
	}
	for name in ['first', 'second', 'third'] {
		app.install_loaded_page(LoadedPage{
			url:          'https://back.example/${name}'
			markup:       '<!doctype html><title>${name}</title><input id="editor" value="text"><textarea id="multiline">text</textarea><div id="editable" contenteditable="true">text</div>'
			content_type: 'text/html'
		}, true)
	}
	return app
}

fn test_command_left_traverses_one_history_entry_and_stops_at_the_beginning() {
	mut app := back_shortcut_test_app()
	defer { app.dispose_browser_tab() }
	for expected in [1, 0, 0] {
		app.handle_key(.left, .super)
		assert app.history_index == expected
		assert app.document.url_string() == app.history[expected].url
		assert app.address == app.history[expected].url
		assert app.history.len == 3
	}
	app.history_go(1)
	assert app.document.url_string() == 'https://back.example/second'
}

fn test_command_left_preserves_address_and_page_text_editing() {
	mut app := back_shortcut_test_app()
	defer { app.dispose_browser_tab() }
	app.focus_address_bar()
	app.handle_key(.left, .super)
	assert app.history_index == 2
	assert app.address_active
	app.native_address_bar = true
	app.handle_key(.left, .super)
	assert app.history_index == 2
	app.native_address_bar = false
	app.blur_address_bar()
	for id in ['editor', 'multiline', 'editable'] {
		element := app.document.get_element_by_id(id) or { panic('missing editor') }
		dom.run_focusing_steps_for_node(element.as_node(), none, .click)
		if id == 'editable' {
			mut selection := app.document.get_selection() or { panic('missing selection') }
			selection.collapse(element.as_node().first_child() or { panic('missing text') }, 4) or {
				panic(err)
			}
		}
		assert app.prepare_page_editing_target() != none
		app.handle_key(.left, .super)
		assert app.history_index == 2
		assert app.document.url_string() == 'https://back.example/third'
	}
	input := app.document.get_element_by_id('editor') or { panic('missing input') }
	model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(input) })
	assert model.value() == 'text'
}

fn test_back_shortcut_ignores_other_arrow_combinations_and_empty_history() {
	mut app := back_shortcut_test_app()
	defer { app.dispose_browser_tab() }
	for modifier in [unsafe { gg.Modifier(0) }, .shift, .ctrl, .alt, .super | .shift, .super | .ctrl,
		.super | .alt] {
		app.handle_key(.left, modifier)
		assert app.history_index == 2
	}
	app.handle_key(.right, .super)
	assert app.history_index == 2
	mut empty := BrowserApp{}
	empty.handle_key(.left, .super)
	assert empty.history.len == 0
}
