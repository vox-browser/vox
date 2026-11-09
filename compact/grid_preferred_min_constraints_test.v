module main

import html
import layout

fn test_grid_intrinsic_tracks_honor_minimum_constraints_on_definite_preferred_sizes() {
 mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:grid;width:min-content;border:5px solid}#item{width:60px;min-width:80px;height:25px;min-height:30px}</style><div id="grid"><div id="item"></div></div>')
 defer { document.finalize() }
 _ = layout.layout_document_typed_in_viewport(document,800,600)
 grid := (document.get_element_by_id('grid') or { panic('grid') }).get_bounding_client_rect()
 assert grid.width==90 && grid.height==40,'${grid.width},${grid.height}'
}
