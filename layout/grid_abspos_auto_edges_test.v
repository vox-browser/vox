module layout

import html

fn test_absolute_grid_auto_edges_use_padding_and_explicit_edges_use_track_lines() {
 for direction in ['ltr','rtl'] {
  for placement, expected in {
   'auto / auto':'0,330'
   '1 / auto': if direction == 'ltr' { '65,265' } else { '0,265' }
   'auto / 2': if direction == 'ltr' { '0,165' } else { '165,165' }
   '1 / 2': if direction == 'ltr' { '65,100' } else { '165,100' }
   '2 / 3': if direction == 'ltr' { '215,50' } else { '65,50' }
  } {
   mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:grid;position:relative;direction:${direction};width:300px;height:100px;padding:15px;grid-template-columns:100px 50px;column-gap:50px;justify-content:center}#item{position:absolute;width:100%;height:10px;grid-column:${placement}}</style><div id="grid"><div id="item"></div></div>')
   defer { document.finalize() }
   _ = layout_document_typed_in_viewport(document,800,600)
   r := (document.get_element_by_id('item') or { panic('item') }).get_bounding_client_rect()
   actual := '${int(r.x)},${int(r.width)}'
   assert actual == expected, '${direction} ${placement}: ${actual}'
  }
 }
}

fn test_absolute_grid_static_alignment_follows_physical_axis_direction() {
 for direction in ['ltr','rtl'] {
  for alignment in ['start','end','center'] {
   mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:grid;position:relative;direction:${direction};width:100px;height:50px;justify-items:${alignment}}#item{position:absolute;width:20px;height:10px}</style><div id="grid"><div id="item"></div></div>')
   defer { document.finalize() }
   _ = layout_document_typed_in_viewport(document,800,600)
   actual := (document.get_element_by_id('item') or { panic('item') }).get_bounding_client_rect().x
   expected := if alignment == 'center' { 40.0 } else if (alignment == 'start') == (direction == 'ltr') { 0.0 } else { 80.0 }
   assert actual == expected, '${direction} ${alignment}: ${actual}'
  }
 }
}
