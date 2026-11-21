module layout

import dom
import html
import os

fn in_place_table_handle(document &dom.Document, id string) voidptr {
	element := document.get_element_by_id(id) or { panic(id) }
	node := element.as_node()
	mirror := node.unsafe_layout_node() or { panic('no box for ${id}') }
	return mirror.real_layout_handle()
}

fn in_place_table_matches_full_rebuild(mut document dom.Document, label string) {
	before := (document.record_display_list() or { panic('paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('full paint') }).dump() == before, label
}

fn in_place_table_append(mut document dom.Document, parent_id string, markup string) {
	mut holder := document.create_element('div') or { panic(err) }
	holder.set_inner_html(markup) or { panic(err) }
	mut child := holder.as_node().first_child() or { panic('child') }
	mut parent := document.get_element_by_id(parent_id) or { panic(parent_id) }
	mut parent_node := parent.as_node()
	parent_node.append_child(child) or { panic(err) }
}

// New and removed subtrees containing tables get the complete builder's
// table fixups (wrappers, dropped whitespace between table parts) and stay
// in place; a changed cell rebuilds its table through escalation. A table
// part outside a table, which joins its siblings' anonymous table, still
// keeps the complete builder. The parent's clearfix pseudo-elements
// (`display: table`) sit in table wrappers and are kept.
fn test_table_subtrees_update_in_place() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0;font:16px/20px sans-serif}td{padding:2px;border:1px solid}#app::before,#app::after{display:table;content:""}</style><body><div id="app"><p id="intro">intro</p></div><p id="tail">tail</p></body>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	enabled := os.getenv('VOX_DISABLE_IN_PLACE_TREE_UPDATE') == ''
		&& os.getenv('VOX_DISABLE_IN_PLACE_TABLES') == ''
	steps := ['table', 'cell', 'nested', 'remove', 'row']
	for step in steps {
		kept_tail := in_place_table_handle(document, 'tail')
		updated_before, _ := in_place_tree_update_statistics()
		match step {
			'table' {
				in_place_table_append(mut document, 'app', '<table id="t">
					<tr><td id="cell">a</td><td>b</td></tr>
				</table>')
			}
			'cell' {
				mut cell := document.get_element_by_id('cell') or { panic('cell') }
				mut cell_node := cell.as_node()
				cell_node.append_child(document.create_text_node(' more').as_node()) or { panic(err) }
			}
			'nested' {
				in_place_table_append(mut document, 'app', '<div id="box"><table><tbody><tr><td>x</td></tr></tbody></table> after</div>')
			}
			'remove' {
				mut table := document.get_element_by_id('t') or { panic('t') }
				table.as_node().remove(false)
			}
			else {
				in_place_table_append(mut document, 'app', '<div style="display:table-row"><span>stray</span></div>')
			}
		}
		document.update_layout(.debugging)
		updated_after, _ := in_place_tree_update_statistics()
		if enabled {
			if step == 'row' {
				assert updated_after == updated_before, step
			} else {
				assert updated_after == updated_before + 1, step
				assert in_place_table_handle(document, 'tail') == kept_tail, step
			}
		}
		in_place_table_matches_full_rebuild(mut document, step)
	}
}
