module layout

import html

fn test_empty_inline_wrappers_do_not_add_block_extent_in_vertical_flow() {
 for mode in ['vertical-lr','vertical-rl'] {
  mut document := html.parse_document('<!doctype html><style>body{margin:0}#scroll{writing-mode:${mode};width:200px;height:200px;overflow:scroll}#scroll::after{content:" ";display:block;width:10px;height:10000px}</style><div id="scroll"><span></span></div>')
  defer { document.finalize() }
  _ = layout_document_typed_in_viewport(document,800,600)
  element := document.get_element_by_id('scroll') or { panic('scroll') }
  assert element.scroll_width() == 200
  assert element.scroll_height() == 10000
 }
}
