module layout

import dom
import html

fn test_grid_abspos_descendants_resolve_their_own_areas_through_static_wrappers() {
 mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:grid;grid-template:50px 100px 150px 200px / 50px 100px 150px 200px;width:500px;height:500px;padding:15px;border:5px solid;position:relative}.absolute{position:absolute;width:100%;height:100%}#a{left:25px;top:75px}#b{grid-column-start:1;grid-row-start:1;right:-40px;bottom:-80px}</style><div id="grid"><div><div id="a" class="absolute"></div><div id="b" class="absolute"></div></div></div>')
 defer { document.finalize() }
 _ = layout_document_typed_in_viewport(document,800,600)
 for id,expected in {'a':[25,75,530,530],'b':[55,95,515,515]} {
  element := document.get_element_by_id(id) or { panic(id) }
  host := unsafe { &dom.HTMLElement(element) }
  assert html.html_element_offset_left(host) == expected[0],id
  assert html.html_element_offset_top(host) == expected[1],id
  assert html.html_element_offset_width(host) == expected[2],id
  assert html.html_element_offset_height(host) == expected[3],id
 }
}

fn test_rtl_overconstrained_abspos_keeps_the_right_inset_with_a_definite_width() {
 mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{position:relative;display:grid;direction:rtl;grid-template:50px 100px 150px 200px / 50px 100px 150px 200px;width:500px;height:500px;padding:15px;border:5px solid}#child{position:absolute;grid-column:3 / span 2;grid-row:3 / span 2;width:100%;height:100%;left:-20px;right:50px;top:-60px;bottom:100px}</style><div id="grid"><div id="child"></div></div>')
 defer { document.finalize() }
 _ = layout_document_typed_in_viewport(document,800,600)
 child := document.get_element_by_id('child') or { panic('child') }
 host := unsafe { &dom.HTMLElement(child) }
 assert html.html_element_offset_left(host) == -35
 assert html.html_element_offset_width(host) == 350
}

fn test_unpositioned_grid_still_supplies_abspos_static_self_alignment() {
 mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:grid;width:800px;height:600px}#child{position:absolute;width:142px;height:62px;place-self:center}</style><div id="grid"><div id="child"></div></div>')
 defer { document.finalize() }
 _ = layout_document_typed_in_viewport(document,800,600)
 child := document.get_element_by_id('child') or { panic('child') }
 rect := child.get_bounding_client_rect()
 assert rect.x == 329 && rect.y == 269, '${rect.x},${rect.y}'
}
