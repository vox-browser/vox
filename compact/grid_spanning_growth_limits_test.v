module main

import css
import dom
import html
import layout

fn test_spanning_grid_minimums_grow_tracks_with_remaining_growth_potential_first() {
 mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:grid-lanes;width:0;font-size:0;grid-template-columns:minmax(auto,max-content) auto}#a{grid-column:1;min-width:40px}#a div{width:30px}#b{grid-column:2}#b span{display:inline-block;width:10px;height:10px}#span{grid-column:1 / 3;min-width:90px}</style><div id="grid"><div id="a"><div></div></div><div id="b"><span></span><span></span><span></span><span></span><span></span></div><div id="span"></div></div>')
 defer { document.finalize() }
 document.set_font_rendering_policy(.chromium)
 _ = layout.layout_document_typed_in_viewport(document,800,600)
 grid := document.get_element_by_id('grid') or { panic('grid') }
 style := css.CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(grid,none))
 actual := style.get_property_value('grid-template-columns')
 assert actual=='40px 50px',actual
}
