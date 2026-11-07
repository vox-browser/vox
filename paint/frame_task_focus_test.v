module main

import dom
import html
import page

fn test_frame_task_layout_preserves_autofocus_before_later_frame_work() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}</style><body></body>')
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{})
	document.update_the_visibility_state(.visible)
	mut navigable := &dom.Navigable{
		active_document_: document
		is_top_level_traversable_: true
	}
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)
	rendering_page := page.Page.create(1) or { panic(err) }
	document.set_page(unsafe { &dom.Page(rendering_page) })
	mut app := BrowserApp{document: document}
	app.relayout(300, 232)
	mut input := document.create_element_ns('http://www.w3.org/1999/xhtml', 'input') or { panic(err) }
	input.set_attribute_value('autofocus', '')
	body := document.body() or { panic('missing body') }
	mut body_node := unsafe { &dom.Node(body.as_node()) }
	body_node.append_child(input.as_node()) or { panic(err) }
	assert document.autofocus_candidates() == [input]
	app.begin_frame_preparation()
	app.synchronize_javascript_task_paint(false)
	assert document.autofocus_processed_flag()
	assert voidptr(document.focused_area()?) == voidptr(input.as_node())
	app.finish_frame_preparation()
	assert document.layout_is_up_to_date()
	assert voidptr(document.focused_area()?) == voidptr(input.as_node())
	// Once autofocus is consumed, the focused editor still needs the complete
	// shell boundary for subsequent changes to its shadow content and geometry.
	app.begin_frame_preparation()
	input.set_attribute_value('style', 'box-sizing:border-box;width:80px')
	app.synchronize_javascript_task_paint(false)
	assert document.layout_is_up_to_date()
	assert input.get_bounding_client_rect().width == 80
	app.finish_frame_preparation()
	assert document.layout_is_up_to_date()
}
