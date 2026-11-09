module layout

import html

fn test_grid_tracks_and_placement_follow_container_writing_axes() {
 for writing, expected in {
  'horizontal-tb;ltr':'33,57,40,60'
  'horizontal-tb;rtl':'127,57,40,60'
  'vertical-lr;ltr':'57,33,60,40'
  'vertical-rl;ltr':'83,33,60,40'
  'vertical-rl;rtl':'83,107,60,40'
 } {
  mode := writing.split(';')
  mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:grid;writing-mode:${mode[0]};direction:${mode[1]};width:200px;height:180px;grid-template-columns:30px 40px;grid-template-rows:50px 60px;column-gap:3px;row-gap:7px}#item{grid-column:2;grid-row:2}</style><div id="grid"><div id="item"></div></div>')
  defer { document.finalize() }
  _ = layout_document_typed_in_viewport(document,800,600)
  item := document.get_element_by_id('item') or { panic('item') }
  r := item.get_bounding_client_rect()
  actual := '${int(r.x)},${int(r.y)},${int(r.width)},${int(r.height)}'
  assert actual == expected, '${writing}: ${actual}'
 }
}

fn test_grid_self_alignment_uses_authored_margins_and_complete_alignment_values() {
 for declaration, expected in {
  'direction:rtl;justify-items:start':'160'
  'direction:rtl;justify-items:end':'0'
  'justify-items:safe center':'80'
  'justify-items:unsafe center':'80'
 } {
  mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:grid;width:200px;grid-template-columns:200px;${declaration}}#item{width:40px;height:20px}</style><div id="grid"><div id="item"></div></div>')
  defer { document.finalize() }
  _ = layout_document_typed_in_viewport(document,800,600)
  r := (document.get_element_by_id('item') or { panic('item') }).get_bounding_client_rect()
  assert '${int(r.x)}' == expected,declaration
 }
}

fn test_grid_non_stretched_width_transfers_a_definite_percentage_height() {
 for writing in ['horizontal-tb','vertical-rl'] {
  mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:grid;width:24px;height:32px}#item{writing-mode:${writing};height:100%;aspect-ratio:1/2;box-sizing:border-box;justify-self:start}</style><div id="grid"><div id="item"></div></div>')
  defer { document.finalize() }
  _ = layout_document_typed_in_viewport(document,800,600)
  r := (document.get_element_by_id('item') or { panic('item') }).get_bounding_client_rect()
  assert r.width == 16 && r.height == 32,'${writing}: ${r.width},${r.height}'
 }
}
