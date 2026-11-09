module main

import css
import dom
import html
import layout

fn test_clip_stays_non_scrollable_next_to_scrollable_overflow_and_preserves_the_flex_main_minimum() {
 for row in [true,false] {
  for scroll_main in [true,false] {
   axis := if row==scroll_main { 'x' } else { 'y' }
   other := if axis=='x' { 'y' } else { 'x' }
   direction := if row { 'row' } else { 'column' }
   cross_size := if row { 'height' } else { 'width' }
   main_size := if row { 'width' } else { 'height' }
   for display in ['block','grid-lanes'] {
    mut document := html.parse_document('<!doctype html><style>body{margin:0}#parent{display:flex;flex-direction:${direction}}#item{display:${display};aspect-ratio:1;${cross_size}:100px;${main_size}:auto;flex-basis:0;overflow-${axis}:hidden;overflow-${other}:clip}#content{width:100px;height:100px}</style><div id="parent"><div id="item"><div id="content"></div></div></div>')
    defer { document.finalize() }
    _ = layout.layout_document_typed_in_viewport(document,800,600)
    item := document.get_element_by_id('item') or { panic('item') }
    style := css.CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(item,none))
    assert style.get_property_value('overflow-${other}')=='clip'
    rect := item.get_bounding_client_rect()
    actual := if row { rect.width } else { rect.height }
    assert actual==if scroll_main { 0.0 } else { 100.0 },'${direction} ${axis} ${display}: ${actual}'
   }
  }
 }
}
