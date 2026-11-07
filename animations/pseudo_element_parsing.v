// Copyright (c) 2024-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/Animations/PseudoElementParsing.{h,cpp}.
module animations

import css

fn pseudo_element_parsing_impl(text string) !css.PseudoElementSelector {
	list := css.parse_selector_with_parser(text, map[string]bool{}) or {
		return error('Invalid pseudo-element selector: "${text}"')
	}
	if list.selectors.len != 1 {
		return error('Invalid pseudo-element selector: "${text}"')
	}
	selector := list.selectors[0]
	compounds := selector.compound_selectors()
	if compounds.len != 1 || compounds[0].simple_selectors.len != 1
		|| compounds[0].simple_selectors[0].type_ != .pseudo_element {
		return error('Invalid pseudo-element selector: "${text}"')
	}
	pseudo := compounds[0].simple_selectors[0].pseudo_element()
	if text in [':before', ':after', ':first-letter', ':first-line'] {
		// Serializing the parsed selector canonicalizes the legacy spelling to
		// the equivalent two-colon selector.
		return css.PseudoElementSelector.new(pseudo.type_)
	}
	return pseudo
}

pub fn pseudo_element_parsing(text string) !css.PseudoElementSelector {
	return pseudo_element_parsing_impl(text)
}
