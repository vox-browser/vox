module layout

import dom
import html
import os

fn first_call_answer_matches_full_rebuild(mut document dom.Document, label string) {
	before := (document.record_display_list() or { panic('paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('full paint') }).dump() == before, label
}

// A clean column flex item that grows is laid out at its automatic height and
// then at its flexed height. Its automatic-height call is answered from the
// first record while a sibling changes, and the item is still laid out again
// when its flexed height becomes its automatic height (here because the
// container's height becomes automatic): its descendants keep the geometry
// of the last call, as a complete rebuild lays them out.
fn test_clean_column_flex_items_answer_their_automatic_height_call() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0;font:16px/20px sans-serif}#column{display:flex;flex-direction:column;height:300px;width:200px}#grow{flex-grow:1;border:1px solid}#grow p{margin:4px}#tail{border:1px solid}</style><body><div id="column"><div id="grow"><p>one</p><p>two words here</p><div style="display:flex"><span>a</span><span>b</span></div></div><div id="tail">tail</div></div></body>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 400)
	// A second pass records each item's first call: the first pass had no
	// committed state to restore from.
	mut tail := document.get_element_by_id('tail') or { panic('tail') }
	mut tail_text := tail.as_node().first_child() or { panic('tail text') }
	tail_text.set_node_value('tail changed') or { panic(err) }
	document.update_layout(.debugging)
	enabled := os.getenv('VOX_DISABLE_FIRST_CALL_ANSWERS') == ''
		&& os.getenv('VOX_DISABLE_INCREMENTAL_LAYOUT') == ''
		&& os.getenv('VOX_DISABLE_MEASUREMENT_SUBTREE_REUSE') == ''
	for step in ['text', 'auto-height'] {
		answered_before := first_call_answer_statistics()
		if step == 'text' {
			tail_text.set_node_value('tail changed again, with more words to wrap onto another line') or {
				panic(err)
			}
		} else {
			mut column := document.get_element_by_id('column') or { panic('column') }
			column.set_attribute_value('style', 'height:auto')
		}
		document.update_layout(.debugging)
		if enabled {
			assert first_call_answer_statistics() > answered_before, step
		}
		first_call_answer_matches_full_rebuild(mut document, step)
	}
}
