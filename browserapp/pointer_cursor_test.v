module main

import dom
import gg
import html
import page
import painting
import sokol.sapp

fn C.sapp_get_mouse_cursor() sapp.MouseCursor

fn pointer_cursor_test_app(markup string) &BrowserApp {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}a,strong,small{display:block}a{width:200px;padding:8px}</style>' + markup)
	mut owner := page.Page.create(1) or { panic(err) }
	document.set_page(unsafe { &dom.Page(owner) })
	_ = html.WindowModel.create_top_level(document, none, 'cursor fixture') or { panic(err) }
	mut app := &BrowserApp{document: document, page_model: owner}
	app.relayout(320, 200 + app.chrome_height())
	return app
}

fn pointer_cursor_test_move(mut app BrowserApp, id string) {
	element := app.document.get_element_by_id(id) or { panic('missing ${id}') }
	rect := element.get_bounding_client_rect()
	app.handle_event(&gg.Event{
		typ: .mouse_move
		mouse_x: f32(rect.x + rect.width / 2)
		mouse_y: f32(rect.y + rect.height / 2) + app.page_top()
	})
}

fn test_native_link_cursor_inherits_through_wikipedia_labels_and_resets_away_from_links() {
	mut app := pointer_cursor_test_app('<a href="https://it.wikipedia.org/" id="link"><strong id="label">Italiano</strong><small id="count">1.989.000+ voci</small></a><a id="no-href">No destination</a>')
	for id in ['label', 'count'] {
		pointer_cursor_test_move(mut app, id)
		assert C.sapp_get_mouse_cursor() == .pointing_hand
	}
	// The empty padding belongs to the link too.
	app.handle_event(&gg.Event{typ: .mouse_move, mouse_x: 2, mouse_y: app.page_top() + 2})
	assert C.sapp_get_mouse_cursor() == .pointing_hand
	pointer_cursor_test_move(mut app, 'no-href')
	assert C.sapp_get_mouse_cursor() != .pointing_hand
	pointer_cursor_test_move(mut app, 'label')
	app.handle_event(&gg.Event{typ: .mouse_move, mouse_x: 10, mouse_y: 10})
	assert C.sapp_get_mouse_cursor() == .arrow
	pointer_cursor_test_move(mut app, 'label')
	app.handle_event(&gg.Event{typ: .mouse_leave})
	assert C.sapp_get_mouse_cursor() == .arrow
}

fn test_native_link_cursor_honors_author_styles_and_live_hover_changes() {
	mut app := pointer_cursor_test_app('<style>#default{cursor:default}#text{cursor:text}#live:hover{cursor:crosshair}</style><a href="#" id="default"><strong id="default-label">Default</strong></a><a href="#" id="text">Text</a><a href="#" id="live">Hover override</a>')
	pointer_cursor_test_move(mut app, 'default-label')
	assert C.sapp_get_mouse_cursor() == .arrow
	pointer_cursor_test_move(mut app, 'text')
	assert C.sapp_get_mouse_cursor() == .ibeam
	pointer_cursor_test_move(mut app, 'live')
	assert C.sapp_get_mouse_cursor() == .crosshair
	mut link := app.document.get_element_by_id('live') or { panic('missing live link') }
	link.set_attribute_value('style', 'cursor:pointer')
	pointer_cursor_test_move(mut app, 'live')
	assert C.sapp_get_mouse_cursor() == .pointing_hand
}

fn test_resize_cursor_takes_precedence_over_link_cursor() {
	mut app := pointer_cursor_test_app('<a href="#" id="link">Resize priority</a>')
	link := app.document.get_element_by_id('link') or { panic('missing link') }
	hit := dom.HitTestResult{element: link, node: link.as_node()}
	assert browser_mouse_cursor_for_hit(hit, none) == .pointing_hand
	assert browser_mouse_cursor_for_hit(hit, painting.ResizeCursor.ew_resize) == .resize_ew
	assert browser_mouse_cursor_for_hit(hit, painting.ResizeCursor.se_resize) == .resize_nwse
	assert browser_mouse_cursor_for_hit(none, none) == .arrow
}
