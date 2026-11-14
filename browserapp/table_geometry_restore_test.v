module main

import dom
import html
import layout

fn table_restore_rectangles(document &dom.Document, ids []string) []dom.Rect {
	mut rectangles := []dom.Rect{}
	for id in ids {
		element := document.get_element_by_id(id) or { panic(id) }
		rectangles << element.get_bounding_client_rect()
	}
	return rectangles
}

fn test_unrelated_incremental_relayout_preserves_table_coordinate_parents() {
	for collapse in ['separate', 'collapse'] {
		mut document := html.parse_document('<!doctype html><style>
			body{margin:32px}#changed{overflow:hidden;height:20px}
			table{width:300px;border:3px solid;border-top:0;border-collapse:${collapse};border-spacing:0}
			td,th{padding:8px;border:1px solid}
		</style><div id="changed">Before</div><table id="table"><caption id="caption">Caption</caption>
		<colgroup id="columns"><col id="column"></colgroup>
		<thead id="head"><tr id="heading"><th id="header">Heading</th></tr></thead>
		<tbody id="body"><tr id="row"><td id="cell">Complete commit message</td></tr></tbody>
		<tfoot id="foot"><tr id="footer"><td>Footer</td></tr></tfoot></table>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout.layout_document_typed_in_viewport(document, 500, 400)
		ids := ['table', 'caption', 'columns', 'column', 'head', 'heading', 'header', 'body', 'row', 'cell', 'foot', 'footer']
		before := table_restore_rectangles(document, ids)
		mut changed := document.get_element_by_id('changed') or { panic('changed') }
		mut text := (changed.as_node().first_child() or { panic('text') }).as_character_data() or { panic('data') }
		for content in ['After', 'Next', 'Final'] {
			count := layout.incremental_layout_pass_count()
			text.set_data(content)
			document.update_layout(.debugging)
			if layout.incremental_layout_pass_count() <= count { panic('incremental path did not execute') }
			after := table_restore_rectangles(document, ids)
			for i, rectangle in after {
				if rectangle != before[i] { panic('incremental table geometry changed: ${collapse} ${ids[i]}') }
			}
		}
	}
}

fn test_clean_table_subtree_reuse_preserves_rows_after_full_page_relayout() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:32px}#container{overflow:hidden;width:300px}
		table{width:100%;border:1px solid;border-top:0;border-collapse:separate;border-spacing:0}
		td{padding:8px}
	</style><div id="container"><table id="table"><tbody id="body"><tr id="row">
	<td id="cell">Complete commit message</td></tr></tbody></table></div>')
	defer { document.finalize() }
	_ = layout.layout_document_typed_in_viewport(document, 500, 400)
	ids := ['table', 'body', 'row', 'cell']
	before := table_restore_rectangles(document, ids)
	for _ in 0 .. 3 {
		count := layout.incremental_layout_reused_subtree_count()
		mut body := document.body() or { panic('body') }
		body.as_node().set_needs_layout_update(.style_change)
		document.update_layout(.debugging)
		if layout.incremental_layout_reused_subtree_count() <= count { panic('subtree reuse did not execute') }
		after := table_restore_rectangles(document, ids)
		for i, rectangle in after {
			if rectangle != before[i] { panic('reused table geometry changed: ${ids[i]}') }
		}
	}
}
