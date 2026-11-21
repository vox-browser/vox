module layout

import dom
import html
import os

fn escaping_absolute_matches_full_rebuild(mut document dom.Document) {
	before := (document.record_display_list() or { panic('missing paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('missing full paint') }).dump() == before
}

fn escaping_absolute_text(document &dom.Document) &dom.Node {
	paragraph := document.get_element_by_id('text') or { panic('text') }
	node := paragraph.as_node()
	return node.first_child() or { panic('text node') }
}

fn escaping_absolute_offset(document &dom.Document, id string) (f64, f64) {
	element := document.get_element_by_id(id) or { panic(id) }
	rect := element.get_bounding_client_rect()
	return rect.x, rect.y
}

// A subtree containing absolute boxes positioned against boxes outside it
// (the initial containing block from their static position, and a resized
// positioned ancestor from its bottom edge) is restored when content above
// it changes, and those boxes are laid out again where the change moved
// them: by a layout tree update (complete pass) and by a text change
// (incremental pass).
fn test_reused_subtree_relays_absolute_boxes_with_outside_containing_blocks() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0;font:16px/20px sans-serif}
		.sr{position:absolute;width:1px;height:1px;overflow:hidden}
		#frame{position:relative}
		#pinned{position:absolute;left:5px;bottom:0;width:10px;height:10px}
		section{display:flow-root}
	</style><body><div id="frame"><div id="changed"><p id="text">first</p></div>
		<section><p>stable text</p><h2 class="sr" id="static">heading</h2><div><span id="pinned"></span></div>
		<p>more stable text</p></section></div><p>tail</p></body>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	mut changed := document.get_element_by_id('changed')?
	mut text := escaping_absolute_text(document)
	_, static_y0 := escaping_absolute_offset(document, 'static')
	_, pinned_y0 := escaping_absolute_offset(document, 'pinned')
	for index in 0 .. 4 {
		reused_before := incremental_layout_reused_subtree_count()
		lines := if index % 2 == 0 { 3 } else { 1 }
		if index < 2 {
			changed.set_inner_html('<p id="text">' + ['line'].repeat(lines).join('<br>') + '</p>') or { panic(err) }
			text = escaping_absolute_text(document)
		} else {
			text.set_node_value(if lines == 3 { 'a long paragraph that wraps onto more than one line in the narrow frame of this test page' } else { 'x' }) or { panic(err) }
		}
		document.update_layout(.debugging)
		reused := incremental_layout_reused_subtree_count() - reused_before
		// The section, besides the inner layouts of both absolute boxes.
		if os.getenv('VOX_RETAIN_ESCAPING_ABSOLUTE_BLOCKING') == '' {
			assert reused >= 3, 'pass ${index}'
		} else {
			assert reused == 2, 'pass ${index}'
		}
		_, static_y := escaping_absolute_offset(document, 'static')
		_, pinned_y := escaping_absolute_offset(document, 'pinned')
		if lines == 3 {
			assert static_y > static_y0, 'pass ${index}'
			assert pinned_y > pinned_y0, 'pass ${index}'
		}
		escaping_absolute_matches_full_rebuild(mut document)
		_, full_static_y := escaping_absolute_offset(document, 'static')
		_, full_pinned_y := escaping_absolute_offset(document, 'pinned')
		assert static_y == full_static_y, 'pass ${index}'
		assert pinned_y == full_pinned_y, 'pass ${index}'
	}
}
