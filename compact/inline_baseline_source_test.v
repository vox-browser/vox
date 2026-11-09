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
