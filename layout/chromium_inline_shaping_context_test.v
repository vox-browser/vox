module layout

import html

fn cross_inline_glyph_advances(markup string) ([]f32, int) {
	mut document := html.parse_document('<!doctype html><style>p{font:12px/16px ui-sans-serif,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;letter-spacing:-.1px}</style><p id="target">${markup}</p>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	result := run_document_layout(document, 800, 600) or { panic('layout') }
	mut pending := [result.root]
	for pending.len > 0 {
		node := pending.pop()
		if source := node.dom_node() {
			if element := source.as_element() {
				if element.get_attribute_value('id') == 'target' {
					used := result.used_values_for(node.as_node_with_style() or { panic('style') }) or { panic('used') }
					mut advances := []f32{}
					mut count := 0
					for line in used.line_boxes {
						for fragment in line.fragments_ {
							count++
							if run := fragment.glyph_run() {
								for glyph in run.glyphs_ { advances << glyph.advance }
							}
						}
					}
					return advances, count
				}
			}
		}
		pending << node.children()
	}
	panic('target')
}

fn test_compatible_inline_boundaries_keep_native_kerning_without_merging_dom_fragments() {
	$if !macos {
		return
	}
	for markup, text in {
		'Privacy Policy<span>.</span>':              'Privacy Policy.'
		'<span>A</span><a>V</a>':                    'AV'
		'<span style="color:red">N.</span> America': 'N. America'
	} {
		actual, count := cross_inline_glyph_advances(markup)
		expected, _ := cross_inline_glyph_advances(text)
		assert actual == expected
		assert count >= 2
	}
}

fn test_font_and_inline_edge_changes_stop_the_shared_shaping_context() {
	$if !macos {
		return
	}
	for markup in ['<span>A</span><span style="padding-left:1px">V</span>',
		'<span>A</span><span style="font-size:14px">V</span>'] {
		actual, _ := cross_inline_glyph_advances(markup)
		plain, _ := cross_inline_glyph_advances('AV')
		assert actual != plain
	}
}
