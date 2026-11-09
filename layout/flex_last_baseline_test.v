module layout

import html

fn test_wrapped_flex_last_baseline_groups_are_exported_from_the_visual_line() {
 for preference in ['first','last'] {
  for wrap in ['wrap','wrap-reverse'] {
   mut document := html.parse_document('<!doctype html><style>body{margin:0}#outer{display:grid;grid-auto-flow:column;align-items:${preference} baseline;line-height:0;font-size:20px;width:200px}span{display:inline-block;width:1em;height:1em}#inner{display:flex;width:140px;flex-wrap:${wrap};gap:10px;border:5px solid;padding:10px}.aligned{margin-block:10px;align-self:last baseline}</style><div id="outer"><div id="a"><span></span></div><div id="inner"><div style="font-size:10px"><span></span></div><div class="aligned" style="font-size:30px"><span></span></div><div style="font-size:50px"><span></span></div><div style="font-size:60px"><span></span></div><div class="aligned" style="font-size:40px"><span></span></div><div style="font-size:20px"><span></span></div></div></div>')
   defer { document.finalize() }
   _ = layout_document_typed_in_viewport(document,800,600)
   y := (document.get_element_by_id('a') or { panic('a') }).get_bounding_client_rect().y
   expected := if preference == 'last' { 105.0 } else if wrap == 'wrap-reverse' { 45.0 } else { 35.0 }
   assert y == expected, '${preference} ${wrap}: ${y}'
  }
 }
}
