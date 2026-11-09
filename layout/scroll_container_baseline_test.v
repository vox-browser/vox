module layout

import html

fn test_scroll_container_vertical_baselines_are_clamped_to_border_edges() {
 for margin in [-200,0,200] {
  for preference in ['first','last'] {
   mut document := html.parse_document('<!doctype html><style>body{margin:0}#outer{display:grid;grid-auto-flow:column;writing-mode:vertical-rl;align-items:${preference} baseline;line-height:0;font-size:20px;inline-size:300px}span{display:inline-block;width:1em;height:1em}#inner{overflow:hidden;inline-size:100px;block-size:80px;margin:10px;border:5px solid;padding:10px;font-size:30px}#child{margin-block-start:${margin}px}</style><div id="outer"><div id="a"><span></span><br><span></span></div><div id="inner"><div id="child"><span></span><br><span></span></div></div></div>')
   defer { document.finalize() }
   _ = layout_document_typed_in_viewport(document,800,600)
   x := (document.get_element_by_id('a') or { panic('a') }).get_bounding_client_rect().x
   expected := if margin < 0 { if preference == 'first' { 90.0 } else { 110.0 } } else if margin == 0 { if preference == 'first' { 60.0 } else { 50.0 } } else { 0.0 }
   assert x == expected, '${margin} ${preference}: ${x}'
  }
 }
}
