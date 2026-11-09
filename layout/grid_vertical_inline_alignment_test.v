module layout

import html

fn test_vertical_grid_left_right_keywords_align_on_the_inline_axis() {
 for writing_mode in ['vertical-lr','vertical-rl'] {
  for direction in ['ltr','rtl'] {
   for position in ['static','absolute'] {
    for alignment,expected in {'left':10.0,'right':50.0,'center':30.0} {
     mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:grid;position:relative;writing-mode:${writing_mode};direction:${direction};width:100px;height:100px;grid-template-columns:100px;grid-template-rows:100px}#item{position:${position};width:20px;height:40px;margin:10px 0;grid-row:1;grid-column:1;justify-self:${alignment}}</style><div id="grid"><div id="item"></div></div>')
     defer { document.finalize() }
     _ = layout_document_typed_in_viewport(document,800,600)
     y := (document.get_element_by_id('item') or { panic('item') }).get_bounding_client_rect().y
     assert y == expected, '${writing_mode} ${direction} ${position} ${alignment}: ${y}'
    }
   }
  }
 }
}
