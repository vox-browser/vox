module main

import dom
import html
import page

// The shell's first layout is the document's first rendering update. Its
// autofocus flush precedes style and layout, so the first recorded frame
// already contains the focused control instead of being replaced next frame.
fn test_first_relayout_flushes_autofocus_before_recording_paint() {
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
	mut input := document.create_element_ns('http://www.w3.org/1999/xhtml', 'input') or { panic(err) }
	input.set_attribute_value('autofocus', '')
	body := document.body() or { panic('missing body') }
	mut body_node := unsafe { &dom.Node(body.as_node()) }
	body_node.append_child(input.as_node()) or { panic(err) }
	assert document.autofocus_candidates() == [input]
	mut app := BrowserApp{document: document}
	app.relayout(300, 232)
	assert document.autofocus_processed_flag()
	assert document.focused_area()? == input.as_node()
	recorded := document.cached_display_list() or { panic('missing display list') }
	assert document.layout_is_up_to_date()
	assert voidptr(document.cached_display_list() or { panic('lost display list') }) == voidptr(recorded)
}
