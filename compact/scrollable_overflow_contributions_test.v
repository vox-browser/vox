module main

import html
import layout

fn test_scrollable_overflow_keeps_zero_area_axes_margins_and_relative_alignment_bounds() {
 mut document := html.parse_document('<!doctype html><style>body{margin:0}.scroll{width:100px;height:100px;overflow:scroll}.item{width:0;height:200px}#relative{padding:10px 5px}#relative>.item{position:relative;top:-1000px;margin-bottom:50px}#flex{display:flex}#flex>.item{width:50px;height:50px;margin-right:950px}#absolute{position:relative}#absolute>.item{position:absolute;left:-50px;width:10px;height:500px}</style><div class="scroll" id="zero"><div class="item"></div></div><div class="scroll" id="relative"><div class="item"></div></div><div class="scroll" id="flex"><div class="item"></div></div><div class="scroll" id="absolute"><div class="item"></div></div>')
 defer { document.finalize() }
 _ = layout.layout_document_typed_in_viewport(document,800,600)
 for id,expected in {'zero':200,'relative':270,'absolute':100} {
  element := document.get_element_by_id(id) or { panic(id) }
  actual := element.scroll_height()
  assert actual == expected,'${id}: ${actual}'
 }
 element := document.get_element_by_id('flex') or { panic('flex') }
 actual := element.scroll_width()
 assert actual == 950,'${actual}'
}

fn test_scrollable_alignment_bounds_use_the_collapsed_trailing_margin() {
 for direction in ['ltr','rtl'] {
  mut document := html.parse_document('<!doctype html><style>body{margin:0}#scroll{width:100px;height:100px;overflow:scroll;padding:10px 5px;line-height:0;direction:${direction}}#outer{position:relative;width:0;margin-bottom:100px;top:-1000px;direction:ltr}#inner{height:200px;margin-bottom:-50px}</style><div id="scroll"><div id="outer"><div id="inner"></div></div></div>')
  defer { document.finalize() }
  _ = layout.layout_document_typed_in_viewport(document,800,600)
  scroll := document.get_element_by_id('scroll') or { panic('scroll') }
  assert scroll.scroll_height()==270,'${direction}: ${scroll.scroll_height()}'
 }
}

fn test_orthogonal_blocks_keep_their_shrink_to_fit_width_in_scroll_alignment_bounds() {
 for mode in ['vertical-lr','vertical-rl'] {
  margin := if mode=='vertical-lr' { 'right' } else { 'left' }
  inset := if mode=='vertical-lr' { 'left' } else { 'right' }
  mut document := html.parse_document('<!doctype html><style>body{margin:0}#scroll{width:100px;height:100px;overflow:scroll;padding:10px 5px;line-height:0;writing-mode:${mode}}#outer{position:relative;writing-mode:horizontal-tb;direction:ltr;height:0;margin-${margin}:100px;${inset}:-1000px}#inner{width:200px;margin-${margin}:-50px}</style><div id="scroll"><div id="outer"><div id="inner"></div></div></div>')
  defer { document.finalize() }
  _ = layout.layout_document_typed_in_viewport(document,800,600)
  scroll := document.get_element_by_id('scroll') or { panic('scroll') }
  assert scroll.scroll_width()==260,'${mode}: ${scroll.scroll_width()}'
 }
}

fn test_zero_height_box_past_a_reversed_inline_scroll_origin_keeps_only_alignment_bounds() {
 mut document := html.parse_document('<!doctype html><style>body{margin:0}#scroll{width:100px;height:100px;overflow:scroll;padding:10px 5px;line-height:0;writing-mode:vertical-rl;direction:rtl}#item{position:relative;writing-mode:horizontal-tb;direction:ltr;width:200px;height:0;margin-right:50px;left:-1000px}</style><div id="scroll"><div id="item"></div></div>')
 defer { document.finalize() }
 _ = layout.layout_document_typed_in_viewport(document,800,600)
 scroll := document.get_element_by_id('scroll') or { panic('scroll') }
 assert scroll.scroll_width()==260,'${scroll.scroll_width()}'
}

fn test_non_scroll_containers_retain_cross_axis_cssom_overflow_from_absolute_boxes() {
 for overflow in ['visible','scroll'] {
  mut document := html.parse_document('<!doctype html><style>body{margin:0}#box{position:relative;width:100px;height:100px;overflow:${overflow}}#child{position:absolute;left:-50px;top:0;width:10px;height:500px}</style><div id="box"><div id="child"></div></div>')
  defer { document.finalize() }
  _ = layout.layout_document_typed_in_viewport(document,800,600)
  box := document.get_element_by_id('box') or { panic('box') }
  assert box.scroll_height()==if overflow=='visible' { 500 } else { 100 },'${overflow}: ${box.scroll_height()}'
 }
}
