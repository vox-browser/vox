module main

import css
import dom
import html
import layout

fn test_intrinsic_auto_repetitions_use_definite_item_sizes_and_invalidate_when_the_item_changes() {
	for repeat in ['auto-fill', 'auto-fit'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:grid-lanes;width:300px;grid-template-columns:repeat(${repeat},auto)}#child{width:30px;height:50px}</style><div id="grid"><div id="child"></div></div>')
		defer { document.finalize() }
		for size in [30, 60] {
			child := document.get_element_by_id('child') or { panic('child') }
			child.set_attribute_value('style', 'width:${size}px')
			_ = layout.layout_document_typed_in_viewport(document, 800, 600)
			grid := document.get_element_by_id('grid') or { panic('grid') }
			style := css.CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(grid, none))
			actual := style.get_property_value('grid-template-columns')
			mut expected := []string{}
			for index in 0 .. 300 / size {
				expected << if repeat == 'auto-fit' {
					if index == 0 { '300px' } else { '0px' }
				} else {
					'${size}px'
				}
			}
			assert actual == expected.join(' '), '${repeat} ${size}: ${actual}'
		}
	}
}
