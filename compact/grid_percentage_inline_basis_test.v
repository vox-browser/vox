module main

import html
import layout
import css
import dom

fn test_grid_percentage_padding_uses_the_area_inline_axis_in_vertical_writing_modes() {
	for mode in ['vertical-lr', 'vertical-rl'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:grid;writing-mode:${mode};grid-template-columns:100px;height:500px;justify-items:start}#item{padding-left:50%}#inner{width:10px;height:10px}#other{width:10px;height:100%}</style><div id="grid"><div id="item"><div id="inner"></div></div><div id="other"></div></div>')
		defer { document.finalize() }
		_ = layout.layout_document_typed_in_viewport(document, 800, 600)
		item := (document.get_element_by_id('item') or { panic('item') }).get_bounding_client_rect()
		assert item.width == 60 && item.height == 10, '${mode}: ${item.width},${item.height}'
	}
}

fn test_grid_percentage_margins_resolve_against_the_area_inline_axis_in_cssom() {
	for mode in ['vertical-lr', 'vertical-rl'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:grid;writing-mode:${mode};grid-template-columns:100px;height:500px;justify-items:start}#item{margin-left:50%;width:10px;height:10px}#other{width:10px;height:100%}</style><div id="grid"><div id="item"></div><div id="other"></div></div>')
		defer { document.finalize() }
		_ = layout.layout_document_typed_in_viewport(document, 800, 600)
		item := document.get_element_by_id('item') or { panic('item') }
		style := css.CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(item, none))
		assert style.get_property_value('margin-left') == '50px'
	}
}
