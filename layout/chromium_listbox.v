module layout

import css
import dom
import html
import math
import platform

fn chromium_select_listbox(node &Node) bool {
 if node.document().font_rendering_policy()!=.chromium || node.computed_values().appearance()==.none_ { return false }
 owner := node.dom_node() or { return false }
 element := owner.as_element() or { return false }
 return element.is_html_element() && element.local_name()=='select' && (element.has_attribute('multiple') || element.get_attribute_value('size').int()>1)
}

// Native list boxes keep their control intrinsic dimensions when their CSS
// display changes. Containment overrides each specified physical dimension;
// a `none` intrinsic override retains that dimension's native control size.
fn chromium_select_listbox_auto_size(node &Node) css.SizeWithAspectRatio {
 owner := node.dom_node() or { return css.SizeWithAspectRatio{} }
 element := owner.as_element() or { return css.SizeWithAspectRatio{} }
 font := node.first_available_font()
 mut maximum := f32(0)
 for option in css.query_selector_all(element.as_node(),'option') {
  maximum=math.max(maximum,platform.shaped_text_width(f32(resolved_text_spacing_for_shaping(node,.letter_spacing)),f32(resolved_text_spacing_for_shaping(node,.word_spacing)),html.html_option_element_label(unsafe { &dom.HTMLOptionElement(option) }),font,.common))
 }
 rows := if element.get_attribute_value('size').int()>0 { element.get_attribute_value('size').int() } else { 4 }
 metrics := font.inline_metrics()
 inline_size := css_px(math.ceil(f64(maximum)))
 block_size := css_px(math.ceil(f64(metrics.ascent+metrics.descent))).scaled(f64(rows))
 mut width := if grid_is_vertical(node) { block_size } else { inline_size }
 mut height := if grid_is_vertical(node) { inline_size } else { block_size }
 if node.has_size_containment() {
  if value := node.explicit_intrinsic_inner_width() { width=value }
  if value := node.explicit_intrinsic_inner_height() { height=value }
 }
 return css.SizeWithAspectRatio{width:width,height:height}
}
