module layout

import css
import dom
import html

fn test_invalid_anchor_size_computed_min_max_values_and_normal_flow_fallback() {
	mut document := html.parse_document('<!doctype html><style>#container{position:relative;width:200px;height:200px}#target{position:absolute;min-width:anchor-size(width);min-height:calc(anchor-size(height) + 2px);max-width:anchor-size(width,28%);max-height:anchor-size(height)}#flow{width:anchor-size(--a width,42px);height:10px}</style><div id="container"><div id="target"></div><div id="flow"></div></div>')
	defer { document.finalize() }
	run_document_layout(document,800,600) or { panic('layout') }
	target := document.get_element_by_id('target') or { panic('target') }
	style := css.CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(target,none))
	assert style.get_property_value('min-width') == 'auto'
	assert style.get_property_value('min-height') == 'auto'
	assert style.get_property_value('max-width') == '28%'
	assert style.get_property_value('max-height') == 'none'
	flow := document.get_element_by_id('flow') or { panic('flow') }
	assert flow.get_bounding_client_rect().width == 42
}
