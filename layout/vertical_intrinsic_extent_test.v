module layout

import html

fn test_vertical_inline_content_accumulates_each_lines_block_extent() {
 for writing_mode in ['vertical-lr','vertical-rl'] {
  mut document := html.parse_document('<!doctype html><style>body{margin:0}#item{display:inline-block;writing-mode:${writing_mode};line-height:0;font-size:0}span{display:inline-block;vertical-align:top;width:10px;height:10px}</style><div id="item"><span></span><br><span></span><br><span></span></div>')
  defer { document.finalize() }
  _ = layout_document_typed_in_viewport(document,800,600)
  rect := (document.get_element_by_id('item') or { panic('item') }).get_bounding_client_rect()
  assert rect.width == 30, '${writing_mode}: ${rect.width}'
  assert rect.height == 10, '${writing_mode}: ${rect.height}'
 }
}

fn test_vertical_grid_baseline_uses_logical_line_position_instead_of_text_advance() {
 mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:grid;writing-mode:vertical-lr;grid-auto-flow:column;align-items:first baseline;width:100px;height:100px;font-size:10px;line-height:10px}</style><div id="grid"><div id="a">M</div><div id="b">MMMMM</div></div>')
 defer { document.finalize() }
 _ = layout_document_typed_in_viewport(document,800,600)
 a := (document.get_element_by_id('a') or { panic('a') }).get_bounding_client_rect()
 b := (document.get_element_by_id('b') or { panic('b') }).get_bounding_client_rect()
 assert a.width == b.width
 assert a.x == b.x, '${a.x} ${b.x}'
}
