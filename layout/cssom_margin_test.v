module layout

import css
import dom
import html

fn test_cssom_fixed_margins_exclude_block_overconstraint_adjustments() {
	for authored, expected in {'10px': '10px', '30%': '60px', 'auto': '100px'} {
		mut document := html.parse_document('<!doctype html><style>#parent{width:200px}#target{width:0;margin:${authored}}</style><div id="parent"><div id="target"></div></div>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 800, 600)
		target := document.get_element_by_id('target') or { panic('target') }
		mirror := target.as_node().unsafe_layout_node() or { panic('layout') }
		declaration := css.CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(target, none))
		for id in [css.PropertyID.margin_left, .margin_right] {
			value := declaration.style_value_for_computed_property(mirror, id) or { panic('margin') }
			assert value.css_text == expected, '${authored}: ${id}: ${value.css_text}'
		}
	}
}
