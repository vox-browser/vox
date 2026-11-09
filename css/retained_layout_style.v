module css

import dom

fn retained_layout_color_component_is_constant(value &StyleValue) bool {
	return match value {
		NumberStyleValue, PercentageStyleValue { true }
		KeywordStyleValue { value.keyword_ == .none_ }
		else { false }
	}
}

fn retained_layout_rgb_is_constant(rgb &RGBColorStyleValue) bool {
	return rgb.relative_origin_.len == 0 && rgb.r_.len == 1 && rgb.g_.len == 1 && rgb.b_.len == 1
		&& rgb.alpha_.len == 1 && retained_layout_color_component_is_constant(&rgb.r_.value)
		&& retained_layout_color_component_is_constant(&rgb.g_.value)
		&& retained_layout_color_component_is_constant(&rgb.b_.value)
		&& retained_layout_color_component_is_constant(&rgb.alpha_.value)
}

fn retained_layout_color_needs_no_metrics(style &ComputedProperties, property PropertyID) bool {
	value := style.property(property, .no) or { return true }
	if value.css_value_handle == unsafe { nil } { return false }
	typed := unsafe { &TypedStyleValueBox(value.css_value_handle) }
	return match typed.value {
		KeywordStyleValue, ColorStyleValue { true }
		RGBColorStyleValue { retained_layout_rgb_is_constant(&typed.value) }
		else { false }
	}
}

fn retained_layout_values_match(previous &dom.StyleValue, current &dom.StyleValue) bool {
	if voidptr(previous) == voidptr(current) { return true }
	if previous == unsafe { nil } || current == unsafe { nil }
		|| previous.css_value_handle == unsafe { nil } || current.css_value_handle == unsafe { nil } {
		return false
	}
	a := unsafe { &TypedStyleValueBox(previous.css_value_handle) }
	b := unsafe { &TypedStyleValueBox(current.css_value_handle) }
	return match a.value {
		KeywordStyleValue {
			if b.value is KeywordStyleValue { a.value.keyword_ == b.value.keyword_ } else { false }
		}
		DisplayStyleValue {
			if b.value is DisplayStyleValue { a.value.display_ == b.value.display_ } else { false }
		}
		LengthStyleValue {
			if b.value is LengthStyleValue { a.value.length_ == b.value.length_ } else { false }
		}
		ColorStyleValue {
			if b.value is ColorStyleValue { a.value.color_ == b.value.color_ } else { false }
		}
		NumberStyleValue {
			if b.value is NumberStyleValue { a.value.value_ == b.value.value_ } else { false }
		}
		IntegerStyleValue {
			if b.value is IntegerStyleValue { a.value.value_ == b.value.value_ } else { false }
		}
		PercentageStyleValue {
			if b.value is PercentageStyleValue {
				a.value.percentage_ == b.value.percentage_
			} else {
				false
			}
		}
		RGBColorStyleValue {
			retained_layout_rgb_is_constant(&a.value)
				&& if b.value is RGBColorStyleValue { a.value == b.value } else { false }
		}
		else { false }
	}
}

// A no-op restyle installs a new DOM style without applying it to Layout.
// Layout may keep its old immutable values only while the complete raw graph
// and every context used to resolve those values are still identical. This
// compares typed inputs, not equal CSS serialization. Fresh scalar values
// from inherited-style computation are harmless; resource graphs retain the
// identity requirement.
pub fn (previous &ComputedProperties) has_identical_retained_layout_inputs(current &ComputedProperties, document &dom.Document) bool {
	if !previous.computed_values_resolved_ || previous.property_store_ == unsafe { nil }
		|| current.property_store_ == unsafe { nil }
		|| previous.has_animated_properties() || current.has_animated_properties()
		|| previous.has_animated_custom_properties() || current.has_animated_custom_properties()
		|| previous.line_height_ != none || current.line_height_ != none
		|| document.layout_coordinate_scale() != 1
		|| previous.layout_coordinate_scale() != 1 || current.layout_coordinate_scale() != 1 {
		return false
	}
	provenance := previous.geometry_provenance()
	if provenance == unsafe { nil } || voidptr(provenance.document) != voidptr(document)
		|| !provenance.matches(previous)
		|| previous.viewport_rect_ != current.viewport_rect_
		|| previous.root_font_size_px_ != current.root_font_size_px_
		|| previous.root_line_height_px_ != current.root_line_height_px_
		|| previous.root_font_metrics_depend_on_viewport_metrics_ != current.root_font_metrics_depend_on_viewport_metrics_
		|| !computed_geometry_subject_matches(previous.subject_element_, current.subject_element_)
		|| previous.display_before_box_type_transformation_ != current.display_before_box_type_transformation_
		|| previous.property_important_ != current.property_important_
		|| previous.property_inherited_ != current.property_inherited_ {
		return false
	}
	old_fonts := previous.cached_computed_font_list_ or { return false }
	new_fonts := current.cached_computed_font_list_ or { return false }
	computer := current.cached_computed_font_list_owner_
	if computer == unsafe { nil }
		|| current.cached_computed_font_list_generation_ != computer.environment_generation()
		|| voidptr(old_fonts) != voidptr(new_fonts)
		|| voidptr(previous.cached_computed_font_list_owner_) != voidptr(current.cached_computed_font_list_owner_)
		|| previous.cached_computed_font_list_generation_ != current.cached_computed_font_list_generation_
		|| voidptr(previous.cached_first_available_computed_font_) != voidptr(current.cached_first_available_computed_font_) {
		return false
	}
	for index in 0 .. computed_property_page_count {
		a := previous.property_store_.pages[index]
		b := current.property_store_.pages[index]
		if voidptr(a) == voidptr(b) { continue }
		for slot in 0 .. computed_property_page_size {
			if !retained_layout_values_match(a.values[slot], b.values[slot]) { return false }
		}
	}
	// Used system colors can change without replacing a raw keyword value.
	// Keep this validation free of parser/font queries and cooperative callbacks.
	if !retained_layout_color_needs_no_metrics(current, .color)
		|| !retained_layout_color_needs_no_metrics(current, .accent_color) {
		return false
	}
	if scheme := current.property(.color_scheme, .no) {
		if scheme.css_value_handle == unsafe { nil } { return false }
	}
	context := color_resolution_context_for_computed_properties(current, document, CalculationResolutionContext{})
	cache := previous.computed_layout_cache()
	return cache.computed_values_color_ == (context.current_color or { Color{0, 0, 0, 255} })
		&& cache.computed_values_color_scheme_ == (context.color_scheme or { PreferredColorScheme.light })
		&& cache.computed_values_accent_color_ == context.accent_color
}
