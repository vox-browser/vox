module layout

import html

fn test_vertical_inline_grid_uses_its_first_shared_alphabetic_baseline() {
 for mode in ['vertical-lr','vertical-rl'] {
  for orthogonal in [false,true] {
   orientation := if orthogonal { 'writing-mode:horizontal-tb' } else { '' }
   mut document := html.parse_document('<!doctype html><style>body{margin:0}#wrapper{position:relative;writing-mode:${mode};text-orientation:sideways;line-height:0}.black{display:inline-block;width:20px;height:10px}#grid{display:inline-grid;grid-auto-flow:column}#one{width:150px;height:100px}#two{align-self:baseline;width:75px;height:50px;${orientation}}#three{width:100px;height:75px}</style><div id="wrapper"><div id="a" class="black"></div> <div id="grid"><div id="one"></div><div id="two"></div><div id="three"></div></div> <div id="b" class="black"></div></div>')
   defer { document.finalize() }
   _ = layout_document_typed_in_viewport(document,800,600)
   expected := if mode == 'vertical-lr' { 0.0 } else { 75.0 }
   for id in ['a','b','two'] {
    x := (document.get_element_by_id(id) or { panic(id) }).get_bounding_client_rect().x
    assert x == expected, '${mode} ${orthogonal} ${id}: ${x}'
   }
  }
 }
}
