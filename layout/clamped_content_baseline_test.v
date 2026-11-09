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

fn test_vertical_clamped_content_uses_the_visible_lines_for_intrinsic_width() {
 for mode in ['vertical-rl','vertical-lr'] {
  for preference in ['first','last'] {
   mut document := html.parse_document('<!doctype html><style>body{margin:0}#outer{display:grid;grid-auto-flow:column;inline-size:100px;writing-mode:${mode};align-items:${preference} baseline;line-height:0;font-size:30px}span{display:inline-block;width:1em;height:1em}#inner{display:-webkit-box;-webkit-box-orient:vertical;-webkit-line-clamp:3;line-clamp:3 no-ellipsis;border:10px solid;font-size:40px;overflow:hidden}</style><div id="outer"><div id="a"><span></span></div><div id="inner"><span></span><br><span></span><br><span></span><br><span></span><br><span></span></div></div>')
   defer { document.finalize() }
   _ = layout_document_typed_in_viewport(document,800,600)
   x := (document.get_element_by_id('a') or { panic('a') }).get_bounding_client_rect().x
   expected := if (mode == 'vertical-rl') == (preference == 'first') { 95.0 } else { 15.0 }
   assert x == expected, '${mode} ${preference}: ${x}'
   assert (document.get_element_by_id('inner') or { panic('inner') }).get_bounding_client_rect().width == 140
  }
 }
}

fn test_clamping_counts_inline_lines_before_an_interrupting_block() {
 for mode in ['horizontal-tb','vertical-lr','vertical-rl'] {
  for preference in ['first','last'] {
   mut document := html.parse_document('<!doctype html><style>body{margin:0}#outer{display:grid;grid-auto-flow:column;inline-size:100px;writing-mode:${mode};align-items:${preference} baseline;line-height:0;font-size:30px}span{display:inline-block;width:1em;height:1em}#inner{display:-webkit-box;-webkit-box-orient:vertical;line-clamp:3 no-ellipsis;border:10px solid;font-size:40px;overflow:hidden}</style><div id="outer"><div id="a"><span></span></div><div id="inner"><span></span><br><i><span></span><div><span></span><br><span></span><br><span></span></div></i></div></div>')
   defer { document.finalize() }
   _ = layout_document_typed_in_viewport(document,800,600)
   rect := (document.get_element_by_id('a') or { panic('a') }).get_bounding_client_rect()
   actual := if mode == 'horizontal-tb' { rect.y } else { rect.x }
   expected := if mode == 'horizontal-tb' { if preference == 'first' { 20.0 } else { 100.0 } } else if (mode == 'vertical-rl') == (preference == 'first') { 95.0 } else { 15.0 }
   assert actual == expected, '${mode} ${preference}: ${actual}'
  }
 }
}

fn test_vertical_clamp_measures_wrapped_block_content_and_an_early_interrupt() {
 for mode in ['vertical-rl','vertical-lr'] {
  for content in ['<div><span></span><br><span></span><br><span></span><br><span></span><br><span></span></div>','<span></span><div><span></span><br><span></span><br><span></span><br><span></span></div>'] {
   for preference in ['first','last'] {
    mut document := html.parse_document('<!doctype html><style>body{margin:0}#outer{display:grid;grid-auto-flow:column;inline-size:100px;writing-mode:${mode};align-items:${preference} baseline;line-height:0;font-size:30px}span{display:inline-block;width:1em;height:1em}#inner{display:-webkit-box;-webkit-box-orient:vertical;line-clamp:3 no-ellipsis;border:10px solid;font-size:40px;overflow:hidden}</style><div id="outer"><div id="a"><span></span></div><div id="inner">${content}</div></div>')
    defer { document.finalize() }
    _ = layout_document_typed_in_viewport(document,800,600)
    x := (document.get_element_by_id('a') or { panic('a') }).get_bounding_client_rect().x
    expected := if (mode == 'vertical-rl') == (preference == 'first') { 95.0 } else { 15.0 }
    assert x == expected, '${mode} ${preference} ${content}: ${x}'
   }
  }
 }
}
