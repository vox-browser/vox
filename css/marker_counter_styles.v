module css

import dom

fn fixed_symbol_counter_style(name string, symbol string) CounterStyle {
	return CounterStyle.create(name, CounterStyleAlgorithm(GenericCounterStyleAlgorithm{
		type_:.cyclic
		symbol_list:[symbol]
	}), CounterStyleNegativeSign{prefix:'-', suffix:''}, '', ' ',
		[CounterStyleRangeEntry{counter_i64_min, counter_i64_max}], 'decimal',
		CounterStylePad{minimum_length:0, symbol:''})
}

fn is_fixed_marker_counter_style(name string, counter CounterStyle) bool {
	styles := builtin_counter_styles()
	return match name {
		'disc' { counter.equals(styles.disc) }
		'decimal' { counter.equals(styles.decimal) }
		'circle' { counter.equals(styles.circle) }
		'square' { counter.equals(styles.square) }
		'disclosure-open' { counter.equals(styles.disclosure_open) }
		'disclosure-closed' { counter.equals(styles.disclosure_closed) }
		else { false }
	}
}

// These fixed styles cover every integer and cannot be overridden by
// authored @counter-style rules. Their markers need neither named lookup nor
// fallback resolution. Other styles still use the live, tree-scoped registry.
pub fn registered_counter_styles_for_marker(style ListStyleType, element dom.AbstractElement) map[string]CounterStyle {
	if style.kind == .counter_style {
		if counter := style.counter_style {
			if is_fixed_marker_counter_style(style.name, counter) {
				return map[string]CounterStyle{}
			}
		}
	}
	return registered_counter_styles_for_abstract_element(element)
}
