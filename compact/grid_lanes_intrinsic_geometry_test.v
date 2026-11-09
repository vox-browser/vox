module main

import html
import layout

fn test_grid_lanes_min_content_block_size_includes_its_stacked_items() {
 for size in ['min-content','max-content'] {
  mut document := html.parse_document('<!doctype html><style>body{margin:0}#parent{width:600px;height:250px}#grid{display:grid-lanes;grid-template-columns:repeat(auto-fill,100px);width:${size};height:${size};max-width:50%;max-height:80%}#item{grid-column:-2;width:100%;height:200px}</style><div id="parent"><div id="grid"><div id="item"></div></div></div>')
  defer { document.finalize() }
  _ = layout.layout_document_typed_in_viewport(document,800,600)
  grid := (document.get_element_by_id('grid') or { panic('grid') }).get_bounding_client_rect()
  assert grid.width==300 && grid.height==200,'${size}: ${grid.width}x${grid.height}'
 }
}
