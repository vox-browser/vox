module css

import dom

// Content only consults the counter registry for counter()/counters(), including
// alternate text. Ordinary text, quotes, images and normal/none need no registry.
pub fn registered_counter_styles_for_content(style &ComputedProperties, element dom.AbstractElement) map[string]CounterStyle {
	value := style.property(.content, .yes) or { return map[string]CounterStyle{} }
	parsed := style_value_logic_from_dom(.content, value) or { return map[string]CounterStyle{} }
	if parsed is ContentStyleValue {
		for item in parsed.content().values() {
			if item is CounterStyleValue {
				return registered_counter_styles_for_abstract_element(element)
			}
		}
		if alt := parsed.alt_text() {
			for item in alt.values() {
				if item is CounterStyleValue {
					return registered_counter_styles_for_abstract_element(element)
				}
			}
		}
	}
	return map[string]CounterStyle{}
}
