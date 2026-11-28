module layout

import dom
import html
import os

fn relaid_caches_match_full_rebuild(mut document dom.Document, label string) {
	before := (document.record_display_list() or { panic('paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('full paint') }).dump() == before, label
}

// Replacing an inline element with an inline-block one of the same text (at
// the end of the line) lays out the paragraph afresh inside its relayout root. The paragraph's
// committed inline layout, whose inputs still name the removed box and its
// unchanged style, must not supply the painted lines: the text was painted
// both as a line of the paragraph and inside the new atomic box.
fn test_relaid_containers_do_not_paint_committed_lines() {
	mut spans := []string{}
	for index in 0 .. 12 {
		spans << '<span id="s${index}">item ${index}</span> '
	}
	mut document := html.parse_document('<!doctype html><style>body{margin:0;font:16px/20px sans-serif}#box{width:300px;height:200px;overflow:hidden;border:1px solid}.block{display:inline-block;color:red}</style><body><div id="box"><p id="line">${spans.join('')}</p></div><div>after</div></body>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 800, 600)
	_ = layout_document_typed_in_viewport(document, 800, 600)
	// The committed projection keeps the paragraph's lines for reuse.
	_ = (document.record_display_list() or { panic('paint') }).dump()
	before := incremental_layout_pass_count()
	mut line := document.get_element_by_id('line') or { panic('line') }
	mut old := document.get_element_by_id('s0') or { panic('s0') }
	mut replacement := document.create_element('span') or { panic(err) }
	replacement.set_attribute_value('class', 'block')
	replacement.as_node().append_child(document.create_text_node('item 0').as_node()) or { panic(err) }
	line.as_node().remove_child(old.as_node()) or { panic(err) }
	line.as_node().append_child(replacement.as_node()) or { panic(err) }
	document.update_layout(.debugging)
	if os.getenv('VOX_DISABLE_INCREMENTAL_LAYOUT') == '' {
		assert incremental_layout_pass_count() > before
	}
	relaid_caches_match_full_rebuild(mut document, 'replaced')
}
