module layout

import dom
import html
import os

fn committed_inline_roots_box(document &dom.Document, id string) &Node {
	element := document.get_element_by_id(id) or { panic(id) }
	mirror := element.as_node().unsafe_layout_node() or { panic('no box for ${id}') }
	return unsafe { &Node(mirror.real_layout_handle()) }
}

fn committed_inline_roots_match_full_layout(mut document dom.Document, label string) {
	before := (document.record_display_list() or { panic('paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('full paint') }).dump() == before, label
}

// A list item with an outside marker and a table cell lay their lines out
// like a paragraph, so committed layouts retain them; an inside marker is
// part of the lines and keeps its item on the uncached path. The lines match
// a complete layout after a change beside them and after the list is
// renumbered.
fn test_list_items_and_table_cells_keep_committed_inline_lines() {
	enabled := os.getenv('VOX_DISABLE_COMMITTED_LIST_AND_CELL_INLINE_REUSE') == ''
		&& os.getenv('VOX_DISABLE_EXTENDED_INLINE_MEASUREMENT_ROOTS') == ''
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0;font:16px/20px sans-serif}
		#inside{list-style-position:inside}
		td{padding:2px}
	</style><body><ol id="list"><li id="outside">First <b>item</b></li><li id="inside">Second item</li></ol><table><tr><td id="cell">Cell <i>text</i></td><td>other cell</td></tr></table><p id="other">other</p></body>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	assert inline_context_inputs_are_retainable(committed_inline_roots_box(document, 'outside')) == enabled
	assert !inline_context_inputs_are_retainable(committed_inline_roots_box(document, 'inside'))
	assert inline_context_inputs_are_retainable(committed_inline_roots_box(document, 'cell')) == enabled
	mut other := document.get_element_by_id('other') or { panic('other') }
	other.set_attribute_value('style', 'padding-top:3px')
	document.update_layout(.debugging)
	committed_inline_roots_match_full_layout(mut document, 'beside')
	// A new first item renumbers the markers of the others.
	mut list := document.get_element_by_id('list') or { panic('list') }
	mut first := document.create_element('li') or { panic(err) }
	mut first_node := first.as_node()
	first_node.append_child(document.create_text_node('Zeroth').as_node()) or { panic(err) }
	mut list_node := list.as_node()
	outside := document.get_element_by_id('outside') or { panic('outside') }
	list_node.pre_insert(first_node, outside.as_node()) or { panic(err) }
	document.update_layout(.debugging)
	committed_inline_roots_match_full_layout(mut document, 'renumbered')
	// Wider cell content changes the table's column widths.
	mut cell := document.get_element_by_id('cell') or { panic('cell') }
	cell.set_attribute_value('style', 'padding:6px')
	document.update_layout(.debugging)
	committed_inline_roots_match_full_layout(mut document, 'cell padding')
}
