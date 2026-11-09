module layout

import html

fn test_clamped_content_exports_the_last_visible_line_baseline() {
 for wrapped in [false,true] {
  for preference in ['first','last'] {
   spans := '<span></span><br><span></span><br><span></span><br><span></span><br><span></span>'
   content := if wrapped { '<div>${spans}</div>' } else { spans }
   mut document := html.parse_document('<!doctype html><style>body{margin:0}#outer{display:grid;grid-auto-flow:column;width:100px;align-items:${preference} baseline;line-height:0;font-size:30px}span{display:inline-block;width:1em;height:1em}#inner{display:-webkit-box;-webkit-box-orient:vertical;-webkit-line-clamp:3;line-clamp:3 no-ellipsis;border:10px solid;font-size:40px;overflow:hidden}</style><div id="outer"><div id="a"><span></span></div><div id="inner">${content}</div></div>')
   defer { document.finalize() }
   _ = layout_document_typed_in_viewport(document,800,600)
   y := (document.get_element_by_id('a') or { panic('a') }).get_bounding_client_rect().y
   expected := if preference == 'first' { 20.0 } else { 100.0 }
   assert y == expected, '${preference} wrapped=${wrapped}: ${y}'
  }
 }
}

