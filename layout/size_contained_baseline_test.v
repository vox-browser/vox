module layout

import html

fn test_size_contained_descendants_do_not_export_hidden_content_baselines_to_cells() {
 for font_size in [16,40] {
  mut document := html.parse_document('<!doctype html><style>body{margin:0}#outer{contain:strict;width:500px}#cell{display:table-cell;border:1px solid}#child{container-type:size;border:1px solid;font-size:${font_size}px;line-height:1}</style><div id="outer"><div id="cell"><div id="child">Contained text</div></div></div>')
  defer { document.finalize() }
  _ = layout_document_typed_in_viewport(document,800,600)
  cell := (document.get_element_by_id('cell') or { panic('cell') }).get_bounding_client_rect()
  child := (document.get_element_by_id('child') or { panic('child') }).get_bounding_client_rect()
  assert child.height == 2
  assert cell.height == 4, '${font_size}: ${cell.height}'
 }
}
