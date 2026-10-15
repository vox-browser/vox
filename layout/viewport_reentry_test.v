module layout

import dom
import html

fn test_scrolled_viewport_paint_refresh_keeps_layout_and_scroll_origin() {
	document := html.parse_document('<!doctype html><style>html,body{margin:0}body{width:1000px;height:1000px}#target{position:absolute;left:100px;top:90px;width:20px;height:20px;background:rgb(17 34 51)}</style><div id="target"></div>')
	mut window := html.WindowModel.create_top_level(document, none, 'viewport-reentry')!
	_ = layout_document_typed_in_viewport(document, 200, 100)
	mut mutable_document := unsafe { &dom.Document(document) }
	_ = mutable_document.record_display_list() or { panic('missing initial display list') }
	_ = window.scroll(html.ScrollToOptions{ left: 40, top: 70, behavior: .instant })
	before := document_layout_result(document) or { panic('missing initial layout') }
	root := voidptr(before.root)
	handle := document.layout_engine_handle()
	mutable_document.set_needs_repaint_with_invalidation(.paint_commands)
	_ = layout_document_typed_in_viewport(document, 200, 100)
	after := document_layout_result(document) or { panic('missing retained layout') }
	assert voidptr(after.root) == root
	assert document.layout_engine_handle() == handle
	assert document.viewport_rect() == dom.Rect{40, 70, 200, 100}
	assert window.scroll_x() == 40 && window.scroll_y() == 70
	target := document.get_element_by_id('target') or { panic('missing target') }
	assert target.get_bounding_client_rect() == dom.Rect{60, 20, 20, 20}
	_ = mutable_document.record_display_list() or { panic('missing refreshed display list') }
	mutable_document.update_layout(.event_handler_handle_mouse_move)
	assert document.layout_is_up_to_date()
	assert document.layout_engine_handle() == handle
}

fn test_scrolled_viewport_resize_updates_units_and_media_without_resetting_scroll() {
	document := html.parse_document('<!doctype html><style>html,body{margin:0}body{width:1000px;height:1000px}#target{position:absolute;left:100px;top:90px;width:50vw;height:25vh}@media(min-width:300px){#target{width:75vw}}</style><div id="target"></div>')
	mut window := html.WindowModel.create_top_level(document, none, 'viewport-resize')!
	_ = layout_document_typed_in_viewport(document, 200, 100)
	target := document.get_element_by_id('target') or { panic('missing target') }
	assert target.get_bounding_client_rect() == dom.Rect{100, 90, 100, 25}
	_ = window.scroll(html.ScrollToOptions{ left: 40, top: 70, behavior: .instant })
	before := document_layout_result(document) or { panic('missing initial layout') }
	root := voidptr(before.root)
	handle := document.layout_engine_handle()
	_ = layout_document_typed_in_viewport(document, 400, 200)
	after := document_layout_result(document) or { panic('missing resized layout') }
	assert voidptr(after.root) != root
	assert document.layout_engine_handle() != handle
	assert document.viewport_rect() == dom.Rect{40, 70, 400, 200}
	assert window.scroll_x() == 40 && window.scroll_y() == 70
	assert target.get_bounding_client_rect() == dom.Rect{60, 20, 300, 50}
	assert document.layout_is_up_to_date()
}
