module main

import html
import layout

fn test_orthogonal_grid_items_use_their_area_inline_size_for_start_alignment() {
 for mode in ['vertical-lr','vertical-rl'] {
  mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:grid;font-size:0;line-height:0;width:300px;height:80px;place-items:start;grid-template-columns:minmax(min-content,max-content);grid-template-rows:minmax(min-content,max-content)}#item{writing-mode:${mode}}#item span{display:inline-block;width:10px;height:20px}</style><div id="grid"><div id="item"><span></span><span></span><span></span><span></span><span></span></div></div>')
  defer { document.finalize() }
  _ = layout.layout_document_typed_in_viewport(document,800,600)
  item := (document.get_element_by_id('item') or { panic('item') }).get_bounding_client_rect()
  assert item.width==20 && item.height==80,'${mode}: ${item.width}x${item.height}'
 }
}

fn test_orthogonal_grid_intrinsic_width_includes_distributed_row_gaps() {
 mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:inline-grid;font:20px/1 monospace;grid-template-rows:50px 50px;height:200px;justify-content:start;align-content:space-between}#item{grid-row:span 2;writing-mode:vertical-lr}</style><div id="grid"><div id="item">XXX XX X XX X XXX</div></div>')
 defer { document.finalize() }
 _ = layout.layout_document_typed_in_viewport(document,800,600)
 item := (document.get_element_by_id('item') or { panic('item') }).get_bounding_client_rect()
 assert item.width==40 && item.height==200,'${item.width}x${item.height}'
}

fn test_orthogonal_grid_intrinsic_columns_use_fixed_row_inline_constraints() {
 for width in ['min-content','max-content','fit-content'] {
  mut document := html.parse_document('<!doctype html><style>body{margin:0;font-size:0;line-height:0}#grid{display:grid;width:${width};grid-template-rows:50px;grid-template-columns:auto auto}#vertical{writing-mode:vertical-lr}span{display:inline-block;width:25px;height:25px}</style><div id="grid"><div id="vertical"><span></span><span></span><span></span></div><div><span></span><span></span><span></span></div></div>')
  defer { document.finalize() }
  _ = layout.layout_document_typed_in_viewport(document,800,600)
  vertical := (document.get_element_by_id('vertical') or { panic('vertical') }).get_bounding_client_rect()
  assert vertical.width==50 && vertical.height==50,'${width}: ${vertical.width}x${vertical.height}'
 }
}
