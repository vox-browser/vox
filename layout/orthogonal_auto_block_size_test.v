module layout

import html

fn test_orthogonal_grid_auto_block_size_uses_tracks_instead_of_viewport_width() {
 for writing_mode in ['vertical-lr','vertical-rl'] {
  mut document := html.parse_document('<!doctype html><style>body{margin:0;width:400px}#grid{display:grid;writing-mode:${writing_mode};inline-size:100px;grid-template:20px 40px / 100px}</style><div id="grid"><div></div><div></div></div>')
  defer { document.finalize() }
  _ = layout_document_typed_in_viewport(document,800,600)
  rect := (document.get_element_by_id('grid') or { panic('grid') }).get_bounding_client_rect()
  assert rect.width == 60, '${writing_mode}: ${rect.width}'
  assert rect.height == 100
 }
}
