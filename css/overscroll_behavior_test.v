module css

import dom

fn test_overscroll_behavior_parses_shorthand_and_maps_logical_axes() {
 for source in ['auto','none','contain','chain','chain auto','contain none'] {
  assert parse_css_value_logic(.overscroll_behavior,source) != none,source
 }
 for source in ['none auto contain','scroll','auto, none'] { assert parse_css_value_logic(.overscroll_behavior,source) == none,source }
 for mode in ['horizontal-tb','vertical-rl'] {
  mut document := dom.Document.create(dom.url_about_blank())
  defer { document.finalize() }
  mut element := document.create_element('div') or { panic(err) }
  element.set_attribute_value('style','writing-mode:${mode};overscroll-behavior-inline:none;overscroll-behavior-block:contain')
  style := css_style_computer_for(document).compute_style(dom.AbstractElement.new(element,none))
  x := (style.property(.overscroll_behavior_x,.no) or { panic('x') }).css_text
  y := (style.property(.overscroll_behavior_y,.no) or { panic('y') }).css_text
  assert x == if mode == 'horizontal-tb' { 'none' } else { 'contain' },x
  assert y == if mode == 'horizontal-tb' { 'contain' } else { 'none' },y
 }
}
