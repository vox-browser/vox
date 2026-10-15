module main

import css
import dom
import gg
import html
import page

fn hover_test_app() &BrowserApp {
	// Keep Wikipedia's descendant :hover selector and nested link label: the
	// pointer can hit the label, article count, or the link's empty padding.
	mut document := html.parse_document('<!doctype html><style>
		:root { --background-color-interactive: #eaecf0 }
		html, body { margin: 0 }
		.central-featured-lang { width: 240px }
		.link-box { display: block; padding: 8px; text-align: center }
		strong, small { display: block }
		.central-featured-lang .link-box:hover strong { text-decoration: underline }
		.central-featured-lang :hover { background-color: var(--background-color-interactive) }
	</style><div class="central-featured-lang"><a id="italiano" class="link-box" href="https://it.wikipedia.org/">'
		+ '<strong id="label">Italiano</strong><small id="count">1.989.000+ <span>voci</span></small></a></div>'
		+ '<div class="central-featured-lang"><a id="english" class="link-box" href="https://en.wikipedia.org/">English</a></div>')
	mut owner := page.Page.create(1) or { panic(err) }
	document.set_page(unsafe { &dom.Page(owner) })
	_ = html.WindowModel.create_top_level(document, none, 'hover fixture') or { panic(err) }
	mut app := &BrowserApp{document: document, page_model: owner}
	app.relayout(320, 200 + app.chrome_height())
	return app
}

fn hover_test_move(mut app BrowserApp, id string) {
	element := app.document.get_element_by_id(id) or { panic('missing ${id}') }
	rect := element.get_bounding_client_rect()
	app.handle_event(&gg.Event{
		typ: .mouse_move
		mouse_x: f32(rect.x + rect.width / 2)
		mouse_y: f32(rect.y + rect.height / 2) + app.page_top()
	})
}

fn hover_test_background(app &BrowserApp, id string) string {
	element := app.document.get_element_by_id(id) or { panic('missing ${id}') }
	return css.CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(element, none)).get_property_value('background-color')
}

fn test_native_pointer_hover_repaints_wikipedia_language_link_and_clears_previous_link() {
	mut app := hover_test_app()
	assert !app.paint_commands.any(it.color == 'rgb(234 236 240)')
	hover_test_move(mut app, 'label')
	assert hover_test_background(app, 'italiano') == 'rgb(234, 236, 240)'
	assert app.document.get_hovered_node() != none
	app.begin_frame_preparation()
	app.finish_frame_preparation()
	assert app.paint_commands.any(it.color == 'rgb(234 236 240)')

	hover_test_move(mut app, 'english')
	assert hover_test_background(app, 'italiano') == 'rgba(0, 0, 0, 0)'
	assert hover_test_background(app, 'english') == 'rgb(234, 236, 240)'
	app.begin_frame_preparation()
	app.finish_frame_preparation()
	italiano := app.document.get_element_by_id('italiano') or { panic('missing italiano') }
	italiano_rect := italiano.get_bounding_client_rect()
	assert !app.paint_commands.any(it.color == 'rgb(234 236 240)' && it.y < italiano_rect.y + italiano_rect.height)
}

fn test_native_pointer_leaving_window_clears_hover_background_on_next_frame() {
	mut app := hover_test_app()
	hover_test_move(mut app, 'label')
	app.begin_frame_preparation()
	app.finish_frame_preparation()
	assert app.paint_commands.any(it.color == 'rgb(234 236 240)')
	app.handle_event(&gg.Event{typ: .mouse_leave})
	app.begin_frame_preparation()
	app.finish_frame_preparation()
	assert app.document.get_hovered_node() == none
	assert !app.paint_commands.any(it.color == 'rgb(234 236 240)')
}
