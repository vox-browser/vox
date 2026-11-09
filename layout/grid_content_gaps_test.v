module layout

import html

fn test_grid_distributes_only_free_space_in_addition_to_authored_gaps() {
 for alignment,expected in {'space-around':[75.0,345.0],'space-evenly':[100.0,320.0],'space-between':[0.0,420.0]} {
  mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:grid;width:520px;height:520px;grid-template-columns:100px 100px;grid-template-rows:100px 100px;gap:20px;place-content:${alignment}}#grid>div{width:100px;height:100px}</style><div id="grid"><div id="a"></div><div></div><div></div><div id="b"></div></div>')
  defer { document.finalize() }
  _ = layout_document_typed_in_viewport(document,800,600)
  a := (document.get_element_by_id('a') or { panic('a') }).get_bounding_client_rect()
  b := (document.get_element_by_id('b') or { panic('b') }).get_bounding_client_rect()
  assert a.x == expected[0] && a.y == expected[0], '${alignment}: ${a.x} ${a.y}'
  assert b.x == expected[1] && b.y == expected[1], '${alignment}: ${b.x} ${b.y}'
 }
}

fn test_grid_flow_end_computed_alignment_keeps_flex_end_behavior() {
 mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:grid;width:100px;height:100px;grid-template:100px / 100px}#item{width:20px;height:30px;place-self:flex-end}</style><div id="grid"><div id="item"></div></div>')
 defer { document.finalize() }
 _ = layout_document_typed_in_viewport(document,800,600)
 rect := (document.get_element_by_id('item') or { panic('item') }).get_bounding_client_rect()
 assert rect.x == 80 && rect.y == 70
}
