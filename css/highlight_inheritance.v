module css

import dom

// https://drafts.csswg.org/css-pseudo-4/#highlight-cascade
// Only applicable highlight properties inherit through the highlight tree.
// Font metrics and custom properties still come from the originating element.
fn (s &StyleComputer) compute_highlight_inherited_values(mut properties ComputedProperties, cascaded &CascadedProperties, element dom.AbstractElement) {
	pseudo := element.pseudo_element() or { return }
	if pseudo !in [.selection, .highlight, .target_text, .search_text, .spelling_error, .grammar_error] { return }
	origin := dom.AbstractElement.new(element.element(), none)
	if origin_properties := parent_computed_properties(element) {
		properties.highlight_originating_color_ = ColorResolutionContext.for_computed_properties(origin_properties, element.document()).current_color
	}
	mut parent_highlight := ?&ComputedProperties(none)
	if parent := origin.element_to_inherit_style_from() {
		target := dom.AbstractElement{element_:parent.element(), pseudo_element_:pseudo, pseudo_argument:element.pseudo_argument}
		mut computer := unsafe { &StyleComputer(s) }
		// The caller's context contains the child's font metrics. A recursive
		// parent computation must not reuse those metrics for em/lh lengths.
		font_context := computer.cached_font_computation_context
		line_context := computer.cached_line_height_computation_context
		generic_context := computer.cached_generic_computation_context
		computer.clear_computation_context_caches()
		parent_highlight = computer.compute_style_with_seeded_ancestors(target)
		computer.cached_font_computation_context = font_context
		computer.cached_line_height_computation_context = line_context
		computer.cached_generic_computation_context = generic_context
	}
	// Default highlight colors are a pair. An authored color anywhere in the
	// highlight inheritance chain suppresses both defaults, even if it is
	// transparent or the other color retains its initial value.
	properties.highlight_colors_authored_ = if parent := parent_highlight {
		parent.highlight_colors_authored_
	} else { false }
	for id in [PropertyID.color, .background_color] {
		entry_index := cascaded.winning_entry_index(id)
		if entry_index >= 0 && cascaded.entry_node(entry_index).entry.origin == .author {
			properties.highlight_colors_authored_ = true
		}
	}
	for index in 0 .. number_of_longhand_properties {
		id := property_id_from_longhand_index(index) or { continue }
		if !pseudo_element_supports_property(pseudo, id) { continue }
		declaration := cascaded.style_property(id)
		keyword := if specified := declaration {
			computed_interpolation_style_value_keyword(specified.value) or { Keyword.invalid }
		} else { Keyword.invalid }
		if id == .color {
			properties.highlight_color_is_current_color_ = if declaration == none || keyword in [.inherit, .unset] {
				if parent := parent_highlight { parent.highlight_color_is_current_color_ } else { true }
			} else { keyword == .currentcolor }
		}
		if declaration == none || keyword in [.inherit, .unset] {
			value := if inherited := parent_highlight {
				inherited.property(id, .no) or { computed_interpolation_property_initial_value(id) }
			} else if id == .color {
				dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.currentcolor)))
			} else { computed_interpolation_property_initial_value(id) }
			properties.set_property_without_modifying_flags(id, value)
			properties.set_property_inherited(id, .yes)
		} else if id == .color && keyword == .currentcolor {
			properties.set_property_without_modifying_flags(id, dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.currentcolor))))
			properties.set_property_inherited(id, .no)
		}
	}
}

// The painter preserves the color of the layer underneath currentColor,
// which can differ from the originating element for ::first-letter text.
pub fn (properties &ComputedProperties) highlight_colors_authored() bool {
	return properties.highlight_colors_authored_
}

pub fn (properties &ComputedProperties) highlight_color_is_current_color() bool {
	return properties.highlight_color_is_current_color_
}
