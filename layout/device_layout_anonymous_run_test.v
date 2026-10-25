module layout

import dom
import html

// HN comments start with bare text followed by paragraph blocks. On a Retina
// display their anonymous first-line wrapper must inherit the same font as
// the explicit paragraphs, including after a style or display-scale change.
fn test_mixed_comment_text_inherits_the_physical_font_once() {
	for doctype in ['', '<!doctype html>'] {
		mut document := html.parse_document(doctype + '<style>
			body{margin:0;font:10pt Verdana}.comment{font-size:9pt}
		</style><div class="comment" id="comment">This statement stood out to me.<p id="paragraph">LLMs have hardened hundreds of apps where I work.</p>Last line.</div>')
		document.set_font_rendering_policy(.chromium)
		for scale in [1.0, 2.0, 1.0] {
			document.set_layout_coordinate_scale(scale)
			run_document_layout(document, 800, 600) or { panic('layout') }
			comment := document.get_element_by_id('comment') or { panic('comment') }
			paragraph := document.get_element_by_id('paragraph') or { panic('paragraph') }
			assert_anonymous_comment_fonts(comment, paragraph, 12 * scale, scale)
		}
		mut comment := document.get_element_by_id('comment') or { panic('comment') }
		paragraph := document.get_element_by_id('paragraph') or { panic('paragraph') }
		document.set_layout_coordinate_scale(2)
		document.update_layout(.debugging)
		comment.set_attribute_value('style', 'font-size:15px')
		document.update_layout(.debugging)
		assert_anonymous_comment_fonts(comment, paragraph, 30, 2)
		document.finalize()
	}
}

fn assert_anonymous_comment_fonts(comment &dom.Element, paragraph &dom.Element, font_size f64, scale f64) {
	bridge := comment.as_node().layout_node() or { panic('comment layout') }
	parent := unsafe { &Node(bridge.layout_handle) }
	paragraph_bridge := paragraph.as_node().layout_node() or { panic('paragraph layout') }
	paragraph_node := unsafe { &Node(paragraph_bridge.layout_handle) }
	assert paragraph_node.computed_values().resolved_font_size_px() == font_size
	mut wrappers := 0
	for child in parent.children() {
		if !child.is_anonymous() { continue }
		wrappers++
		assert child.computed_values().resolved_font_size_px() == font_size
		assert child.computed_values().layout_coordinate_scale() == scale
		assert child.computed_values().font_size() == paragraph_node.computed_values().font_size()
	}
	assert wrappers == 2
}
