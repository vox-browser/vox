module layout

import css
import dom
import html
import math
import platform

fn chromium_menu_list(node &Node) bool {
	if node.document().font_rendering_policy() != .chromium
		|| node.computed_values().appearance() == .none_ {
		return false
	}
	dom_node := node.dom_node() or { return false }
	element := dom_node.as_element() or { return false }
	return html.html_select_element_uses_chromium_menu_list(element)
}

// Blink LayoutBox::MenuListIntrinsic{Inline,Block}Size. All option labels
// contribute using the select's font, including options that are not selected.
// Round once in native layout coordinates, after shaping the complete label.
fn chromium_menu_list_auto_size(node &Node) css.SizeWithAspectRatio {
	dom_node := node.dom_node() or { return css.SizeWithAspectRatio{} }
	element := dom_node.as_element() or { return css.SizeWithAspectRatio{} }
	font := node.first_available_font()
	values := node.computed_values()
	letter_spacing := f32(resolved_text_spacing_for_shaping(node, .letter_spacing))
	word_spacing := f32(resolved_text_spacing_for_shaping(node, .word_spacing))
	mut maximum := f32(0)
	for option in css.query_selector_all(element.as_node(), 'option') {
		mut label := html.html_option_element_label(unsafe { &dom.HTMLOptionElement(option) })
		if parent := option.as_node().parent_element() {
			if parent.local_name() == 'optgroup' { label = '    ' + label }
		}
		label = apply_text_transform_for_text_node(label, values.text_transform(), element.lang() or { '' })
		maximum = math.max(maximum, platform.shaped_text_width(letter_spacing, word_spacing,
			label, font, .common))
	}
	scale := node.document().layout_coordinate_scale()
	padding := 4 + 1 + html.chromium_menu_list_arrow_padding()
	inline_size := CSSPixels.nearest_value_for(math.ceil(f64(maximum)) + padding * scale)
	metrics := font.inline_metrics()
	block_size := CSSPixels.nearest_value_for(f64(metrics.ascent + metrics.descent) + 2 * scale)
	return if values.writing_mode() == .horizontal_tb {
		css.SizeWithAspectRatio{ width: inline_size, height: block_size }
	} else {
		css.SizeWithAspectRatio{ width: block_size, height: inline_size }
	}
}
