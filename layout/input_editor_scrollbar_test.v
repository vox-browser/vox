module layout

import html

// Computed scrollbar-width of every scrollable element box except the viewport.
fn input_editor_scrollbar_widths(node &Node, mut widths []string) {
	if dom_node := node.dom_node() {
		values := node.computed_values()
		if !node.is_viewport() && dom_node.is_element() && values.overflow_y() in [.auto_, .scroll] {
			widths << '${values.scrollbar_width()}'
		}
	}
	for child in node.children() {
		input_editor_scrollbar_widths(child, mut widths)
	}
}

// A text input's internal editor scrolls to keep its caret visible but never
// shows a scrollbar (HTMLInputElement::create_text_input_shadow_tree()). A
// painted editor scrollbar is also a nested overlay at the end of the paint
// order, which disqualified Hacker News's search box from scroll raster reuse.
fn test_text_input_editors_never_paint_scrollbars() {
	mut document := html.parse_document('<!doctype html><style>body { margin:0 } input { font-family:monospace; font-size:10pt }</style><form>Search: <input type="text" name="q" size="17"></form><input value="Hello gjpqy"><input type="search" placeholder="Find"><div style="height:2000px"></div>')
	defer { document.finalize() }
	for ratio in [1.0, 2.0] {
		document.set_display_device_pixel_ratio(ratio)
		_ = layout_document_typed_in_viewport(document, 1024, 768)
		result := document_layout_result(document) or { panic('missing layout') }
		mut widths := []string{}
		input_editor_scrollbar_widths(result.root, mut widths)
		assert widths == ['none_', 'none_', 'none_'], '${widths}'
		commands := display_list_commands(document.record_viewport_display_list() or {
			panic('missing display list')
		})
		scrollbars := commands.filter(it.scrollbar_axis != '')
		assert scrollbars.len > 0 && scrollbars.all(it.x >= 1024 - 30), '${scrollbars.map(it.x)}'
		assert viewport_scroll_raster_reusable(document, commands, 1024, 768)
	}
}
