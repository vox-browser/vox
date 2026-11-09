module layout

import html
import dom

fn test_offset_geometry_includes_sticky_displacement_relative_to_the_offset_parent() {
 for own_scroll in [false,true] {
  overflow := if own_scroll { 'overflow:auto' } else { '' }
  mut document := html.parse_document('<!doctype html><style>body{margin:0}#scroll{overflow:auto;height:500px}#grid{position:relative;display:grid;grid-template-rows:100px 100px 100px 300px;height:400px;${overflow}}#item{position:sticky;top:40px;width:20px;height:20px;transform:translateY(100px)}</style><div id="scroll"><div style="height:30px"></div><div id="grid"><div id="item"></div></div><div style="height:2000px"></div></div>')
  defer { document.finalize() }
  _ = layout_document_typed_in_viewport(document,800,600)
  item := document.get_element_by_id('item') or { panic('item') }
  host := unsafe { &dom.HTMLElement(item) }
  expected := if own_scroll { 40 } else { 10 }
  assert html.html_element_offset_top(host) == expected
 }
}
