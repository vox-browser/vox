module main

import css
import dom
import html
import layout

fn test_grid_lanes_minimum_contributions_break_cyclic_preferred_minimum_and_maximum_percentages() {
 names := ['auto','min','max','size','min max','min size','max size','min max size']
 for row in [true,false] {
  axis := if row { 'rows' } else { 'columns' }
  for index,name in names {
   mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:grid-lanes;width:50px;height:50px;grid-template-${axis}:auto}.min{min-width:calc(100% + 50px);min-height:calc(100% + 50px)}.max{max-width:calc(100% - 50px);max-height:calc(100% - 50px)}.size{width:calc(100% + 10px);height:calc(100% + 10px)}#content{width:100px;height:100px}</style><div id="grid"><div class="${name}"><div id="content"></div></div></div>')
   defer { document.finalize() }
   _ = layout.layout_document_typed_in_viewport(document,800,600)
   grid := document.get_element_by_id('grid') or { panic('grid') }
   style := css.CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(grid,none))
   actual := style.get_property_value('grid-template-${axis}')
   expected := [100,50,100,100,50,50,100,50][index]
   assert actual=='${expected}px','${axis} ${name}: ${actual}'
  }
 }
}
