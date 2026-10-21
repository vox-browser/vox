module css

import dom

// These two fixed styles cover every integer and cannot be overridden by
// authored @counter-style rules. Their markers need neither named lookup nor
// fallback resolution. Other styles still use the live, tree-scoped registry.
pub fn registered_counter_styles_for_marker(style ListStyleType, element dom.AbstractElement) map[string]CounterStyle {
	if style.kind == .counter_style {
		if counter := style.counter_style {
			if (style.name == 'disc' && counter.equals(builtin_counter_styles().disc))
				|| (style.name == 'decimal' && counter.equals(builtin_counter_styles().decimal)) {
				return map[string]CounterStyle{}
			}
		}
	}
	return registered_counter_styles_for_abstract_element(element)
}
