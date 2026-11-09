module main

import html
import layout

fn test_inline_blocks_export_explicit_first_and_last_baseline_sets() {
	for source in ['first', 'last'] {
		for display in ['inline-block', 'inline-flex', 'inline-grid'] {
			mut document := html.parse_document('<!doctype html><style>body{margin:0}#outer{line-height:0;font-size:20px}#reference{display:inline-block;width:20px;height:20px}#inner{display:${display};baseline-source:${source};flex-direction:column;font-size:30px;line-height:0;border:5px solid;padding:10px}#inner span{display:inline-block;width:30px;height:30px}</style><div id="outer"><span id="reference"></span><div id="inner"><div><span></span></div><div><span></span></div></div></div>')
			defer { document.finalize() }
			_ = layout.layout_document_typed_in_viewport(document, 800, 600)
			reference := (document.get_element_by_id('reference') or { panic('reference') }).get_bounding_client_rect()
			inner := (document.get_element_by_id('inner') or { panic('inner') }).get_bounding_client_rect()
			offset := reference.y - inner.y
			expected := if source == 'first' { 25.0 } else { 55.0 }
			assert offset == expected, '${display} ${source}: ${offset}'
		}
	}
}

fn test_explicit_first_baselines_skip_fieldset_legend_and_include_table_caption() {
 mut document := html.parse_document('<!doctype html><style>body{margin:0}.target{width:200px;padding:10px;line-height:0;font-size:20px}.inner{border:5px solid;padding:10px;baseline-source:first;font-size:30px}span{display:inline-block;width:1em;height:1em}table{border-spacing:0}tr{vertical-align:baseline}td{padding:0}caption{margin:10px;height:20px}</style><div class="target"><span id="field-reference"></span><fieldset class="inner" style="display:inline-block"><span></span><br><span></span><legend><span></span></legend></fieldset></div><div class="target" id="table-target"><span id="table-reference"></span><table class="inner" style="display:inline-table"><caption></caption><tr><td><span></span><br><span></span></td></tr></table></div>')
 defer { document.finalize() }
 _ = layout.layout_document_typed_in_viewport(document,800,600)
 field := (document.get_element_by_id('field-reference') or { panic('field') }).get_bounding_client_rect()
 assert field.y == 60,'${field.y}'
 table := (document.get_element_by_id('table-reference') or { panic('table') }).get_bounding_client_rect()
 target := (document.get_element_by_id('table-target') or { panic('target') }).get_bounding_client_rect()
 assert table.y-target.y == 75,'${table.y-target.y}'
}
