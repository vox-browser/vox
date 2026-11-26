module layout

import html
import os

// On a large tree, a change whose relayout root holds a quarter of the boxes
// skips the incremental attempt (its automatic size change would discard
// it) and runs the complete pass with subtree reuse; a small root still
// relays out incrementally, and small trees always attempt.
fn test_large_relayout_roots_run_the_complete_pass() {
	mut rows := []string{}
	for index in 0 .. 300 {
		rows << '<p>row ${index}</p>'
	}
	mut document := html.parse_document('<!doctype html><style>body{margin:0;font:16px/20px sans-serif}</style><body><div id="big" style="overflow:hidden">${rows.join('')}<span id="grow">x</span></div><div id="small" style="height:40px;overflow:hidden"><span id="text">small</span></div></body>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	_ = layout_document_typed_in_viewport(document, 400, 300)
	retained := os.getenv('VOX_RETAIN_LARGE_RELAYOUT_ROOTS') != ''
	mut text := document.get_element_by_id('text') or { panic('text') }
	before := incremental_layout_pass_count()
	text.set_attribute_value('style', 'padding-left:20px')
	document.update_layout(.debugging)
	assert incremental_layout_pass_count() == before + 1
	mut grow := document.get_element_by_id('grow') or { panic('grow') }
	before_large := incremental_layout_pass_count()
	grow.set_attribute_value('style', 'padding-left:20px')
	document.update_layout(.debugging)
	if !retained {
		assert incremental_layout_pass_count() == before_large
	}
	listed := (document.record_display_list() or { panic('paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('full paint') }).dump() == listed
}
