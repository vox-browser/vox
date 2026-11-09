module layout

import html

fn test_vertical_flex_exports_both_baselines_in_visual_item_order() {
 mut actuals := []string{}
 for preference in ['first','last'] {
  for direction in ['row','row-reverse'] {
   mut document := html.parse_document('<!doctype html><style>body{margin:0}#outer{display:grid;grid-auto-flow:column;writing-mode:vertical-rl;align-items:${preference} baseline;line-height:0;font-size:20px;inline-size:200px}span{display:inline-block;width:1em;height:1em}#inner{display:flex;flex-direction:${direction};border:5px solid;padding:10px}</style><div id="outer"><div id="a"><span></span></div><div id="inner"><div style="font-size:10px"><span></span></div><div style="font-size:30px"><span></span></div></div></div>')
   defer { document.finalize() }
   _ = layout_document_typed_in_viewport(document,800,600)
   x := (document.get_element_by_id('a') or { panic('a') }).get_bounding_client_rect().x
   inner := (document.get_element_by_id('inner') or { panic('inner') }).get_bounding_client_rect()
   actuals << '${preference} ${direction}: ${x} inner=${inner.x},${inner.width}'
  }
 }
 assert actuals == ['first row: 30.0 inner=0.0,60.0','first row-reverse: 20.0 inner=0.0,60.0','last row: 20.0 inner=0.0,60.0','last row-reverse: 30.0 inner=0.0,60.0'], actuals.str()
}

fn test_flex_logical_directions_project_main_cross_axes_and_gaps() {
 cases := [
  ['horizontal-tb','ltr','row','0,0;15,0'],
  ['horizontal-tb','rtl','row','50,0;35,0'],
  ['horizontal-tb','rtl','row-reverse','0,0;15,0'],
  ['vertical-rl','ltr','row','50,0;50,25'],
  ['vertical-rl','ltr','row-reverse','50,60;50,35'],
  ['vertical-rl','rtl','row','50,60;50,35'],
  ['vertical-rl','ltr','column','50,0;37,0'],
  ['vertical-rl','ltr','column-reverse','0,0;13,0'],
  ['vertical-lr','ltr','column','0,0;13,0'],
 ]
 for entry in cases {
  mut document := html.parse_document('<!doctype html><style>body{margin:0}#flex{display:flex;width:60px;height:80px;writing-mode:${entry[0]};direction:${entry[1]};flex-direction:${entry[2]};gap:3px 5px}#flex>div{width:10px;height:20px;flex:none}</style><div id="flex"><div id="a"></div><div id="b"></div></div>')
  defer { document.finalize() }
  _ = layout_document_typed_in_viewport(document,800,600)
  a := (document.get_element_by_id('a') or { panic('a') }).get_bounding_client_rect()
  b := (document.get_element_by_id('b') or { panic('b') }).get_bounding_client_rect()
  actual := '${int(a.x)},${int(a.y)};${int(b.x)},${int(b.y)}'
  assert actual == entry[3], '${entry[0]} ${entry[1]} ${entry[2]}: ${actual}'
 }
}
