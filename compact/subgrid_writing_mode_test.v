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

fn test_subgridded_axes_stretch_even_when_self_alignment_requests_another_position() {
 for alignment in ['start','end','center','baseline'] {
  mut document := html.parse_document('<!doctype html><style>body{margin:0;font-size:0}#parent{display:inline-grid;grid-template:100px / 100px}#child{display:grid;grid-template:subgrid / subgrid;margin:10px;padding:10px;border:10px solid;align-self:${alignment};justify-self:${alignment}}</style><div id="parent"><div id="child"><div id="item"></div></div></div>')
  defer { document.finalize() }
  _ = layout.layout_document_typed_in_viewport(document,800,600)
  item := (document.get_element_by_id('item') or { panic('item') }).get_bounding_client_rect()
  assert item.x==30 && item.y==30 && item.width==40 && item.height==40,'${alignment}: ${item.x},${item.y} ${item.width}x${item.height}'
 }
}

fn test_row_subgrid_keeps_provisional_intrinsic_tracks_during_parent_placement_changes() {
 mut document := html.parse_document('<!doctype html><style>body{margin:0}#parent{height:200px;display:grid-lanes;grid-lanes-direction:row;grid-template-rows:[start] auto [end] 1fr}#child{display:grid;grid-row:1 / -1;grid-template-rows:subgrid}#item{height:50px;border:5px solid;grid-row:start / end}</style><div id="parent"><div id="child"><div id="item"></div></div></div>')
 defer { document.finalize() }
 _ = layout.layout_document_typed_in_viewport(document,800,600)
 parent := document.get_element_by_id('parent') or { panic('parent') }
 parent.set_attribute_value('style','grid-template-rows:1fr [start] auto [end]')
 _ = layout.layout_document_typed_in_viewport(document,800,600)
 item := (document.get_element_by_id('item') or { panic('item') }).get_bounding_client_rect()
 assert item.y==140,'${item.y}'
}

fn test_nested_subgrids_share_baselines_through_border_padding_and_gap_edges() {
 pair := '<div class="item first"><span></span><br><span></span></div><div class="item last"><span></span><br><span></span></div>'
 mut document := html.parse_document('<!doctype html><style>body{margin:0}.item{inline-size:40px;box-sizing:border-box;border:5px solid;line-height:0;margin-block-start:3px;margin-block-end:5px}.small{width:30px;height:30px}.first{align-self:baseline}.last{align-self:last baseline}span{width:20px;height:20px;box-sizing:border-box;border:5px solid;display:inline-block}</style><div style="writing-mode:vertical-rl;width:600px;position:relative;display:grid;grid-template:150px 150px 150px / 100px 100px 100px 100px"><div style="display:grid;gap:10px;grid-column:1/span 2;grid-row:1/span 3;grid-template:subgrid/subgrid;margin-block-start:5px;margin-block-end:10px;border:5px solid;padding-block-start:10px;padding-block-end:20px"><div style="display:grid;gap:20px;grid-column:1/span 2;grid-row:1/span 2;grid-template:subgrid/subgrid;margin-block-start:3px;margin-block-end:7px;border:5px solid;padding-block-start:5px;padding-block-end:10px">${pair}${pair}</div>${pair}</div><div class="item small first"></div><div class="item small last"></div><div class="item small first"></div><div class="item small last"></div><div class="item small first"></div><div class="item small last"></div></div>')
 defer { document.finalize() }
 _ = layout.layout_document_typed_in_viewport(document,800,600)
 expected := [514,465,387,332,242,190,534,465,407,332,262,190]
 mut actual := []int{}
 for item in css.query_selector_all(document.as_node(),'.item') {
  actual << html.html_element_offset_left(unsafe { &dom.HTMLElement(item) })
 }
 assert actual==expected,actual.str()
}
