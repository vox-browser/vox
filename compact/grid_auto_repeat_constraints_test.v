module main

import html
import layout

fn test_auto_repeat_counts_definite_minimum_and_maximum_constraints_on_both_axes() {
 for maximum in [false,true] {
  constraint := if maximum { 'max' } else { 'min' }
  mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:grid;float:left;grid-template-columns:repeat(auto-fill,100px);grid-template-rows:repeat(auto-fill,50px);${constraint}-width:300px;${constraint}-height:200px}#item{grid-column:-2;grid-row:-2}</style><div id="grid"><div id="item"></div></div>')
  defer { document.finalize() }
  _ = layout.layout_document_typed_in_viewport(document,800,600)
  rect := (document.get_element_by_id('grid') or { panic('grid') }).get_bounding_client_rect()
  item := (document.get_element_by_id('item') or { panic('item') }).get_bounding_client_rect()
  assert rect.width == 300 && rect.height == 200,'${constraint} ${rect.width},${rect.height}'
  assert item.x == 200 && item.y == 150,'${constraint} ${item.x},${item.y}'
 }
}
