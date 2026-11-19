module css

import dom
import os

// Same-binary control: under device layout a restyle always rebuilds the
// boxes of its elements, as before.
const disable_device_layout_style_reuse = os.getenv('VOX_DISABLE_DEVICE_LAYOUT_STYLE_REUSE') != ''
// VOX_RETAINED_LAYOUT_STYLE_DIAGNOSTICS=1 prints the first input that kept
// Layout from retaining its values across a restyle.
const retained_layout_style_diagnostics = os.getenv('VOX_RETAINED_LAYOUT_STYLE_DIAGNOSTICS') != ''

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
//
// Under device layout `previous` is the projection of the old DOM style into
// physical coordinates, while the DOM keeps CSS pixels. The replacement is
// projected the same way and compared in those coordinates: its projection
// shares the property pages that the old projection took from unchanged
// sources, and every other input is compared as at scale 1.
pub fn (previous &ComputedProperties) has_identical_retained_layout_inputs(replacement &ComputedProperties, document &dom.Document) bool {
	difference := previous.retained_layout_input_difference(replacement, document)
	if retained_layout_style_diagnostics && difference != '' {
		eprintln('Vox retained layout style: differs=${difference} scale=${document.layout_coordinate_scale()}')
	}
	return difference == ''
}

// The first input that keeps Layout from retaining `previous`, or '' when
// every input is identical.
fn (previous &ComputedProperties) retained_layout_input_difference(replacement &ComputedProperties, document &dom.Document) string {
	mut current := unsafe { replacement }
	if document.layout_coordinate_scale() != 1 {
		// The projection materializes animated samples and scales a resolved
		// line height; reject those before they become ordinary values.
		if disable_device_layout_style_reuse { return 'device-layout-control' }
		if replacement.layout_coordinate_scale() != 1 || replacement.property_store_ == unsafe { nil } {
			return 'replacement'
		}
		if replacement.has_animated_properties() || replacement.has_animated_custom_properties() {
			return 'animated'
		}
		if replacement.line_height_ != none { return 'line-height' }
		current = computed_style_in_layout_coordinates(replacement, document)
		// The box already holds the projection of this very style.
		if voidptr(current) == voidptr(previous) {
			return if previous.computed_values_resolved_ { '' } else { 'unresolved' }
		}
	}
	if !previous.computed_values_resolved_ { return 'unresolved' }
	if previous.property_store_ == unsafe { nil } || current.property_store_ == unsafe { nil } {
		return 'store'
	}
	if previous.has_animated_properties() || current.has_animated_properties()
		|| previous.has_animated_custom_properties() || current.has_animated_custom_properties() {
		return 'animated'
	}
	if previous.line_height_ != none || current.line_height_ != none { return 'line-height' }
	if previous.layout_coordinate_scale() != current.layout_coordinate_scale() { return 'scale' }
	provenance := previous.geometry_provenance()
	if provenance == unsafe { nil } || voidptr(provenance.document) != voidptr(document)
		|| !provenance.matches(previous) {
		return 'provenance'
	}
	if previous.viewport_rect_ != current.viewport_rect_
		|| previous.root_font_size_px_ != current.root_font_size_px_
		|| previous.root_line_height_px_ != current.root_line_height_px_
		|| previous.root_font_metrics_depend_on_viewport_metrics_ != current.root_font_metrics_depend_on_viewport_metrics_ {
		return 'context'
	}
	if previous.subject_is_pseudo_ != current.subject_is_pseudo_
		|| !computed_geometry_subject_matches(previous.subject_element_, current.subject_element_) {
		return 'subject'
	}
	if previous.display_before_box_type_transformation_ != current.display_before_box_type_transformation_
		|| previous.property_important_ != current.property_important_
		|| previous.property_inherited_ != current.property_inherited_ {
		return 'flags'
	}
	old_fonts := previous.cached_computed_font_list_ or { return 'fonts' }
	new_fonts := current.cached_computed_font_list_ or { return 'fonts' }
	computer := current.cached_computed_font_list_owner_
	if computer == unsafe { nil }
		|| current.cached_computed_font_list_generation_ != computer.environment_generation()
		|| voidptr(previous.cached_computed_font_list_owner_) != voidptr(current.cached_computed_font_list_owner_)
		|| previous.cached_computed_font_list_generation_ != current.cached_computed_font_list_generation_ {
		return 'font-generation'
	}
	if current.layout_coordinate_scale() == 1 {
		if voidptr(old_fonts) != voidptr(new_fonts)
			|| voidptr(previous.cached_first_available_computed_font_) != voidptr(current.cached_first_available_computed_font_) {
			return 'fonts'
		}
	} else if voidptr(old_fonts) != voidptr(new_fonts) {
		// A font list keeps its projection only without pending author faces
		// and where that projection may outlive the document. Otherwise each
		// style projects the list again: the box's list must still select what
		// this replacement's fonts project to. A projection takes its first
		// available font from that list alone.
		source_fonts := replacement.cached_computed_font_list_ or { return 'fonts' }
		factor := current.layout_coordinate_scale() / replacement.layout_coordinate_scale()
		if !device_layout_fonts_select_alike(source_fonts, old_fonts, factor,
			replacement.resolved_font_size_px() * factor) {
			return 'fonts'
		}
	}
	for index in 0 .. computed_property_page_count {
		a := previous.property_store_.pages[index]
		b := current.property_store_.pages[index]
		if voidptr(a) == voidptr(b) { continue }
		for slot in 0 .. computed_property_page_size {
			if !retained_layout_values_match(a.values[slot], b.values[slot]) {
				if retained_layout_style_diagnostics {
					property_ids := computed_interpolation_longhand_property_ids()
					id := index * computed_property_page_size + slot
					return if id < property_ids.len { 'value:${property_ids[id]}' } else { 'value' }
				}
				return 'value'
			}
		}
	}
	// Used system colors can change without replacing a raw keyword value.
	// Keep this validation free of parser/font queries and cooperative callbacks.
	if !retained_layout_color_needs_no_metrics(current, .color)
		|| !retained_layout_color_needs_no_metrics(current, .accent_color) {
		return 'color-metrics'
	}
	if scheme := current.property(.color_scheme, .no) {
		if scheme.css_value_handle == unsafe { nil } { return 'color-scheme' }
	}
	context := color_resolution_context_for_computed_properties(current, document, CalculationResolutionContext{})
	cache := previous.computed_layout_cache()
	if cache.computed_values_color_ != (context.current_color or { Color{0, 0, 0, 255} })
		|| cache.computed_values_color_scheme_ != (context.color_scheme or { PreferredColorScheme.light })
		|| cache.computed_values_accent_color_ != context.accent_color {
		return 'used-color'
	}
	return ''
}
