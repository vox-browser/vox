module layout

import html

fn test_sliced_inline_fragments_hit_padding_with_only_the_unbroken_corners_rounded() {
	for mode in ['horizontal-tb', 'vertical-lr', 'vertical-rl'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#parent{margin:40px;writing-mode:${mode}}#span{padding:20px;line-height:100px;font-size:40px;border-radius:40px;background:yellow}</style><div id="parent"><span id="span">FOO<br>BAR</span></div>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 800, 600)
		element := document.get_element_by_id('span') or { panic('span') }
		rects := element.get_client_rects()
		assert rects.len == 2, '${mode}: ${rects.len}'
		for index, rect in rects {
			// The first fragment keeps its inline-start corners; the second keeps
			// its inline-end corners. The two cut edges remain rectangular.
			for right in [false, true] {
				for bottom in [false, true] {
					rounded := if mode == 'horizontal-tb' {
						right == (index == 1)
					} else {
						bottom == (index == 1)
					}
					for inset in [5.0, 20.0] {
						x := if right { rect.x_ + rect.width_ - inset } else { rect.x_ + inset }
						y := if bottom { rect.y_ + rect.height_ - inset } else { rect.y_ + inset }
						hit := document.element_from_point(x, y) or { panic('missing hit') }
						expected := if rounded && inset == 5 { 'parent' } else { 'span' }
						assert hit.get_attribute_value('id') == expected, '${mode} ${index} ${right} ${bottom} ${inset}: ${hit.get_attribute_value('id')}'
					}
				}
			}
		}
	}
}
