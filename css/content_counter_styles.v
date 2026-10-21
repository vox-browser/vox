module css

import dom

// Content only consults the counter registry for counter()/counters(), including
// alternate text. Ordinary text, quotes, images and normal/none need no registry.
pub fn registered_counter_styles_for_content(style &ComputedProperties, element dom.AbstractElement) map[string]CounterStyle {
	if content_references_counter_styles(style) {
		return registered_counter_styles_for_abstract_element(element)
	}
	return map[string]CounterStyle{}
}

fn content_references_counter_styles(style &ComputedProperties) bool {
	value := style.property(.content, .yes) or { return false }
	parsed := style_value_logic_from_dom(.content, value) or { return false }
	if parsed is ContentStyleValue {
		for item in parsed.content().values() {
			if item is CounterStyleValue {
				return true
			}
		}
		if alt := parsed.alt_text() {
			for item in alt.values() {
				if item is CounterStyleValue {
					return true
				}
			}
		}
	}
	return false
}

// Layout keeps one registry snapshot across initial content and counter
// resolution. An absent registry needs no per-element mutable empty map.
pub struct ContentCounterStyles {
	styles ?map[string]CounterStyle
}

__global empty_content_counter_styles_ = map[string]CounterStyle{}

pub fn content_counter_styles_for_layout(style &ComputedProperties, element dom.AbstractElement) ContentCounterStyles {
	if content_references_counter_styles(style) {
		return ContentCounterStyles{styles:registered_counter_styles_for_abstract_element(element)}
	}
	return ContentCounterStyles{}
}

pub fn (styles ContentCounterStyles) resolve_content(style &ComputedProperties, element &dom.AbstractElement, nesting_level u32) ContentDataAndQuoteNestingLevel {
	if registered := styles.styles { return style.content(element, nesting_level, registered) }
	// This map is private and only passed to read-only content evaluation. The
	// public registry getter above still returns an independently mutable map.
	return style.content(element, nesting_level, empty_content_counter_styles_)
}
