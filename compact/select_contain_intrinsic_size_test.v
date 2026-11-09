module main

import html
import layout

fn test_native_listbox_keeps_intrinsic_axes_without_containment_overrides() {
 for rows in [2,4,10] {
  mut document := html.parse_document('<!doctype html><style>body{margin:0}select{padding:0}.test{display:grid-lanes;contain:size;border:1px solid}#width{contain-intrinsic-size:55px none}#height{contain-intrinsic-size:none 66px}</style><select id="reference" multiple size="${rows}"></select><select id="width" class="test" multiple size="${rows}"></select><select id="height" class="test" multiple size="${rows}"></select>')
  defer { document.finalize() }
  document.set_font_rendering_policy(.chromium)
  _ = layout.layout_document_typed_in_viewport(document,800,600)
  reference := (document.get_element_by_id('reference') or { panic('reference') }).get_bounding_client_rect()
  width := (document.get_element_by_id('width') or { panic('width') }).get_bounding_client_rect()
  height := (document.get_element_by_id('height') or { panic('height') }).get_bounding_client_rect()
  assert width.width==57 && width.height==reference.height,'${rows}: ${width.width}x${width.height}, reference ${reference.height}'
  assert height.height==68 && height.width==reference.width,'${rows}: ${height.width}x${height.height}, reference ${reference.width}'
 }
}
