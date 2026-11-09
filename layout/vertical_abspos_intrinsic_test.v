module layout

import html

fn test_vertical_absolute_content_height_uses_the_longest_unwrapped_line() {
 for writing_mode in ['vertical-lr','vertical-rl'] {
  mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:grid;position:relative;writing-mode:${writing_mode};width:100px;height:150px;grid-template:100px / 150px;font-size:0;line-height:0}#item{position:absolute;grid-row:1;grid-column:1;place-self:start}span{display:inline-block;vertical-align:top;width:10px}</style><div id="grid"><div id="item"><span style="height:40px"></span><br><span style="height:70px"></span><br><span style="height:60px"></span></div></div>')
  defer { document.finalize() }
  _ = layout_document_typed_in_viewport(document,800,600)
  rect := (document.get_element_by_id('item') or { panic('item') }).get_bounding_client_rect()
  assert rect.width == 30 && rect.height == 70, '${writing_mode}: ${rect.width} ${rect.height}'
 }
}
