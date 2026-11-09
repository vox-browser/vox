module layout

import html

fn test_vertical_grid_exports_shared_baselines_from_its_outermost_tracks() {
 for mode in ['vertical-rl','vertical-lr'] {
  for alignment in ['first','last'] {
   mut document := html.parse_document('<!doctype html><style>body{margin:0}#outer{display:grid;grid-auto-flow:column;writing-mode:${mode};align-items:first baseline;line-height:0;font-size:20px;inline-size:300px}span{display:inline-block;width:1em;height:1em}#inner{display:grid;gap:10px;grid-template:50px 50px / 50px 50px 50px;border:5px solid;padding:10px;align-items:${alignment} baseline}#inner>div:first-child,#inner>div:last-child{align-self:start}</style><div id="outer"><div id="a"><span></span></div><div id="inner"><div style="font-size:20px"><span></span></div><div style="font-size:10px"><span></span></div><div style="font-size:30px"><span></span></div><div style="font-size:15px"><span></span></div><div style="font-size:35px"><span></span></div><div style="font-size:25px"><span></span></div></div></div>')
   defer { document.finalize() }
   _ = layout_document_typed_in_viewport(document,800,600)
   x := (document.get_element_by_id('a') or { panic('a') }).get_bounding_client_rect().x
   expected := if mode == 'vertical-rl' { if alignment == 'first' { 100.0 } else { 80.0 } } else { if alignment == 'first' { 20.0 } else { 40.0 } }
   assert x == expected, '${mode} ${alignment}: ${x}'
  }
 }
}
