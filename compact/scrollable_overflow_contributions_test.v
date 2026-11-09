module main

import html
import layout

fn test_scrollable_overflow_keeps_zero_area_axes_margins_and_relative_alignment_bounds() {
 mut document := html.parse_document('<!doctype html><style>body{margin:0}.scroll{width:100px;height:100px;overflow:scroll}.item{width:0;height:200px}#relative{padding:10px 5px}#relative>.item{position:relative;top:-1000px;margin-bottom:50px}#flex{display:flex}#flex>.item{width:50px;height:50px;margin-right:950px}#absolute{position:relative}#absolute>.item{position:absolute;left:-50px;width:10px;height:500px}</style><div class="scroll" id="zero"><div class="item"></div></div><div class="scroll" id="relative"><div class="item"></div></div><div class="scroll" id="flex"><div class="item"></div></div><div class="scroll" id="absolute"><div class="item"></div></div>')
 defer { document.finalize() }
 _ = layout.layout_document_typed_in_viewport(document,800,600)
 for id,expected in {'zero':200,'relative':270,'absolute':500} {
  element := document.get_element_by_id(id) or { panic(id) }
  actual := element.scroll_height()
  assert actual == expected,'${id}: ${actual}'
 }
 element := document.get_element_by_id('flex') or { panic('flex') }
 actual := element.scroll_width()
 assert actual == 950,'${actual}'
}
