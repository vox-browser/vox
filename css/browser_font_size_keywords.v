module css

import dom

// Chromium FontSizeFunctions' default proportional and fixed-font rows.
// https://chromium.googlesource.com/chromium/src/+/main/third_party/blink/renderer/core/css/font_size_functions.cc
fn absolute_size_mapping_for_document(size AbsoluteSize, default_size CSSPixels, document &dom.Document) CSSPixels {
	if document.font_size_keyword_policy() == .chromium {
		index := int(size)
		if default_size == CSSPixels.new(16) {
			return CSSPixels.new([9, 10, 13, 16, 18, 24, 32, 48][index])
		}
		if default_size == CSSPixels.new(13) {
			values := if document.in_quirks_mode() {
				[9, 9, 10, 13, 16, 20, 26, 40]
			} else {
				[9, 10, 12, 13, 16, 20, 26, 39]
			}
			return CSSPixels.new(values[index])
		}
	}
	return StyleComputer.absolute_size_mapping(size, default_size)
}

fn compute_font_size_with_document_policy(value &dom.StyleValue, depth int,
	parent ?dom.AbstractElement, context ComputationContext) &dom.StyleValue {
	if element := context.abstract_element {
		if element.document().font_size_keyword_policy() != .chromium {
			return StyleComputer.compute_font_size(value, depth, parent)
		}
		parsed := style_value_logic_from_dom(.font_size, value) or {
			return StyleComputer.compute_font_size(value, depth, parent)
		}
		if size := computed_interpolation_keyword_to_absolute_size(parsed.to_keyword()) {
			pixels := absolute_size_mapping_for_document(size,
				StyleComputer.default_user_font_size(), element.document())
			return dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_css_px(pixels))))
		}
	}
	return StyleComputer.compute_font_size(value, depth, parent)
}
