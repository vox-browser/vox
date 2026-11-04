module layout

import dom
import html

fn projection_style_document() &dom.Document {
	return html.parse_document('<!doctype html><style>html,body{margin:0}#tab{position:relative;width:200px;height:40px;background:rgb(26 38 55)}#bar{position:absolute;left:0;bottom:0;width:100%;height:2px;background:rgb(169 210 255);transform-origin:left}section{overflow:hidden;width:200px}#spacer{height:1000px}</style><div id="changed"></div><div id="tab">Tab<span id="bar" style="transform:scaleX(0.25)"></span></div><div id="spacer"></div><section id="clip"><p id="text">Offscreen comment</p></section>')
}

fn projection_style_project(mut document dom.Document) &DocumentLayoutResult {
	_ = document.record_viewport_display_list() or { panic('missing native recording') }
	mut changed := document.get_element_by_id('changed') or { panic('missing trigger') }
	changed.set_inner_html('<p>Changed preceding flow</p>') or { panic(err) }
	document.update_layout(.debugging)
	return document_layout_result(document) or { panic('missing projection') }
}

// A per-frame transform update inside the viewport keeps the projection that
// omits offscreen content, and paints as the complete transport would.
fn test_style_updates_inside_the_paint_interest_keep_the_viewport_projection() {
	mut document := projection_style_document()
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 100)
	mut result := projection_style_project(mut document)
	assert result.paint_projection_incomplete
	text_id := i64((document.get_element_by_id('text') or { panic('missing text') }).as_node().unique_id())
	assert result.paint_tree.find_box(text_id) == none
	mut bar := document.get_element_by_id('bar') or { panic('missing bar') }
	for scale in ['0.5', '0.75'] {
		bar.set_attribute_value('style', 'transform:scaleX(${scale})')
		document.update_layout(.html_event_loop_rendering_update)
		projected := (document.record_viewport_display_list() or { panic('missing projected paint') }).dump()
		assert result.paint_projection_incomplete
		assert result.paint_tree.find_box(text_id) == none
		// A complete rebuild of the same projection paints identically.
		refresh_document_paint_tree(document, mut result, 320, 100)
		assert result.paint_projection_incomplete
		assert (document.record_viewport_display_list() or { panic('missing rebuilt paint') }).dump() == projected
	}
	// An update inside an omitted subtree restores the complete transport.
	mut text := document.get_element_by_id('text') or { panic('missing text') }
	text.set_attribute_value('style', 'color:red')
	document.update_layout(.html_event_loop_rendering_update)
	_ = document.record_viewport_display_list() or { panic('missing restored paint') }
	assert !result.paint_projection_incomplete
	assert result.paint_tree.find_box(text_id) != none
}
