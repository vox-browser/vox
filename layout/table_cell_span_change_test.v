module layout

import dom
import html

fn missing_cell_count(node &Node) int {
	mut count := if node.is_missing_table_cell() { 1 } else { 0 }
	for child in node.children() { count += missing_cell_count(child) }
	return count
}

fn test_table_cell_span_attribute_rebuilds_anonymous_missing_cells() {
	for attribute in ['colspan', 'rowspan'] {
		mut document := html.parse_document('<!doctype html><table id="table"><tr><td id="target">A</td><td>B</td></tr><tr><td>C</td><td>D</td></tr></table>')
		document.set_browsing_context(&dom.BrowsingContext{})
		initial := run_document_layout(document, 300, 150) or { panic('missing layout') }
		assert missing_cell_count(initial.root) == 0
		mut cell := document.get_element_by_id('target') or { panic('missing cell') }
		table := document.get_element_by_id('table') or { panic('missing table') }
		cell.set_attribute_value(attribute, '2')
		assert table.as_node().needs_layout_tree_update_()
		document.update_layout(.debugging)
		changed := document_layout_result(document) or { panic('missing changed layout') }
		assert missing_cell_count(changed.root) == 1
		cell.set_attribute_value(attribute, '1')
		document.update_layout(.debugging)
		restored := document_layout_result(document) or { panic('missing restored layout') }
		assert missing_cell_count(restored.root) == 0
	}
}
