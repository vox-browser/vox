module layout

import html

fn test_cyclic_percentage_height_preserves_the_aspect_ratio_minimum_after_inline_stretch() {
	for display in ['block', 'table'] {
		for writing_mode in ['horizontal-tb', 'vertical-rl'] {
			for alignment in ['normal', 'stretch', 'start'] {
				// Orthogonal non-stretching cases have a definite physical height.
				if writing_mode == 'vertical-rl' && alignment != 'start' { continue }
				mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:inline-grid;width:24px;height:32px}#item{display:${display};writing-mode:${writing_mode};height:100%;box-sizing:border-box;aspect-ratio:1/2;justify-self:${alignment}}</style><div id="grid"><div id="item"></div></div>')
				defer { document.finalize() }
				_ = layout_document_typed_in_viewport(document, 800, 600)
				item := (document.get_element_by_id('item') or { panic('item') }).get_bounding_client_rect()
				expected_width := if alignment == 'start' { 16.0 } else { 24.0 }
				expected_height := if alignment == 'start' { 32.0 } else { 48.0 }
				assert item.width == expected_width && item.height == expected_height, '${display} ${writing_mode} ${alignment}: ${item.width},${item.height}'
			}
		}
	}
}
