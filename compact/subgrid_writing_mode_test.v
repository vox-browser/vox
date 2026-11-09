module main

import css
import dom
import html
import layout

fn test_orthogonal_subgrid_cssom_preserves_the_logical_subgrid_axis() {
	for columns in [true, false] {
		axis := if columns { 'columns' } else { 'rows' }
		placement := if columns { 'column' } else { 'row' }
		child_axis := if columns { 'rows' } else { 'columns' }
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#parent{display:inline grid-lanes;grid-lanes-direction:${placement};grid-template-${axis}:repeat(6,20px)}#child{display:grid;writing-mode:vertical-lr;grid-${placement}:2 / span 4;grid-template-${child_axis}:subgrid [] [] [] [] [x]}</style><div id="parent"><div id="child"></div></div>')
		defer { document.finalize() }
		_ = layout.layout_document_typed_in_viewport(document, 800, 600)
		child := document.get_element_by_id('child') or { panic('child') }
		style := css.CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(child, none))
		actual := style.get_property_value('grid-template-${child_axis}')
		assert actual == 'subgrid [] [] [] [] [x]', actual
	}
}

fn test_grid_lanes_stacking_axis_cannot_supply_subgrid_tracks() {
	for columns in [true, false] {
		axis := if columns { 'columns' } else { 'rows' }
		direction := if columns { 'column' } else { 'row' }
		ignored := if columns { 'rows' } else { 'columns' }
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#parent{display:grid-lanes;grid-lanes-direction:${direction};grid-template-${axis}:100px 100px}#child{display:grid;grid-template-${ignored}:subgrid [a] [b]}</style><div id="parent"><div id="child"></div></div>')
		defer { document.finalize() }
		_ = layout.layout_document_typed_in_viewport(document, 800, 600)
		child := document.get_element_by_id('child') or { panic('child') }
		style := css.CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(child, none))
		actual := style.get_property_value('grid-template-${ignored}')
		assert actual == 'none', actual
	}
}
