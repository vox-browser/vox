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

fn test_grid_lanes_auto_repeat_resolves_percentage_minimum_from_a_definite_parent() {
 mut document := html.parse_document('<!doctype html><style>body{margin:0}#parent{height:1000px}#lanes{display:grid-lanes;float:left;width:100px;grid-template-rows:repeat(auto-fill,20%);min-height:50%}#lanes>div{width:100px;height:100%}</style><div id="parent"><div id="lanes"><div>1</div><div>2</div><div>3</div><div>4</div><div>5</div></div></div>')
 defer { document.finalize() }
 _ = layout.layout_document_typed_in_viewport(document,800,600)
 element := document.get_element_by_id('lanes') or { panic('lanes') }
 rect := element.get_bounding_client_rect()
 assert rect.height == 500,'${rect.height}'
 for child in element.as_node().children_as_vector() {
  if item := child.as_element() { actual := item.get_bounding_client_rect().height;assert actual == 100,'${actual}' }
 }
}
