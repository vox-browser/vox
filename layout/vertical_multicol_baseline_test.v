module layout

import html

fn test_vertical_atomic_column_sets_and_spanners_export_extreme_baselines() {
 for mode in ['vertical-rl','vertical-lr'] {
  for spanner in ['none','start','end'] {
   for preference in ['first','last'] {
    span := '<div style="column-span:all"><span></span><br><span></span></div>'
    children := '<div style="font-size:10px"><span></span><br><span></span><br><span></span></div><div style="font-size:30px"><span></span><br><span></span><br><span></span></div><div style="font-size:20px"><span></span><br><span></span><br><span></span></div>'
    content := if spanner == 'start' { span+children } else if spanner == 'end' { children+span } else { children }
    mut document := html.parse_document('<!doctype html><style>body{margin:0}#outer{display:grid;grid-auto-flow:column;inline-size:200px;writing-mode:${mode};align-items:${preference} baseline;line-height:0;font-size:20px}span{display:inline-block;width:1em;height:1em}#inner{columns:3;column-fill:auto;padding:10px;border:10px solid}#inner>div{break-inside:avoid;break-before:column;break-after:column}</style><div id="outer"><div id="a"><span></span></div><div id="inner">${content}</div></div>')
    defer { document.finalize() }
    _ = layout_document_typed_in_viewport(document,800,600)
    x := (document.get_element_by_id('a') or { panic('a') }).get_bounding_client_rect().x
    expected := if mode == 'vertical-rl' { if preference == 'first' { if spanner == 'none' { 95.0 } else if spanner == 'start' { 130.0 } else { 135.0 } } else { if spanner == 'end' { 20.0 } else { 25.0 } } } else { if preference == 'first' { if spanner == 'start' { 20.0 } else { 15.0 } } else { if spanner == 'none' { 85.0 } else if spanner == 'start' { 125.0 } else { 130.0 } } }
    assert x == expected, '${mode} ${spanner} ${preference}: ${x}'
   }
  }
 }
}
