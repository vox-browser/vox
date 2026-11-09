module layout

import html

fn test_table_client_dimensions_use_the_anonymous_wrapper_padding_box() {
 mut document := html.parse_document('<!doctype html><style>body{margin:0}#outer{contain:strict;width:500px}#table{display:table;border:1px solid}#child{container-type:size;border:1px solid}</style><div id="outer"><div id="table"><div id="child"></div></div></div>')
 defer { document.finalize() }
 _ = layout_document_typed_in_viewport(document,800,600)
 table := document.get_element_by_id('table') or { panic('table') }
 rect := table.get_bounding_client_rect()
 assert rect.width == 4 && rect.height == 4, '${rect.width} ${rect.height}'
 assert table.client_width() == 4
 assert table.client_height() == 4
}
