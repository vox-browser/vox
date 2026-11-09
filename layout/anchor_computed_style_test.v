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

fn test_anchor_size_fallback_preserves_mixed_percentage_calculation_in_computed_maximum() {
	mut document := html.parse_document('<!doctype html><style>#container{position:relative;width:200px;height:200px}#target{position:absolute;max-width:anchor-size(width,calc(28% + 1px));max-height:calc(28% + anchor-size(height,1px))}</style><div id="container"><div id="target"></div></div>')
	defer { document.finalize() }
	run_document_layout(document,800,600) or { panic('layout') }
	target := document.get_element_by_id('target') or { panic('target') }
	style := css.CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(target,none))
	assert style.get_property_value('max-width') == 'calc(28% + 1px)'
	assert style.get_property_value('max-height') == 'calc(28% + 1px)'
}

fn test_invalid_anchor_inside_a_calculated_maximum_does_not_clamp_intrinsic_content_to_zero() {
	mut document := html.parse_document('<!doctype html><style>#container{position:relative;width:200px;height:200px}#container>div{position:absolute}#width{max-width:calc(anchor-size(width) + 10px)}#height{max-height:calc(anchor-size(height) + 10px)}</style><div id="container"><div id="ref">X</div><div id="width">X</div><div id="height">X</div></div>')
	defer { document.finalize() }
	run_document_layout(document,800,600) or { panic('layout') }
	reference := (document.get_element_by_id('ref') or { panic('ref') }).get_bounding_client_rect()
	assert reference.width > 0 && reference.height > 0
	for id in ['width','height'] {
		r := (document.get_element_by_id(id) or { panic(id) }).get_bounding_client_rect()
		assert r.width == reference.width && r.height == reference.height,'${id}: ${r.width}, ${r.height}'
	}
}
