module css

import dom
import platform

// Cache the style's font inputs, keeping container-query lookup state local
// to each resolution context so layout changes remain visible to cq units.
@[heap]
struct ComputedLengthMetrics {
	font_size_value &dom.StyleValue
	line_height_value &dom.StyleValue
	line_height ?CSSPixels
	font &PlatformFont
	root_font_size f64
	root_line_height f64
	font_metrics LengthFontMetrics
	root_font_metrics LengthFontMetrics
}

fn (c &ComputedProperties) length_font_metrics() &ComputedLengthMetrics {
	font_size_value := c.property(.font_size, .yes) or { unsafe { &dom.StyleValue(nil) } }
	line_height_value := c.property(.line_height, .yes) or { unsafe { &dom.StyleValue(nil) } }
	cached := c.cached_length_metrics_
	if cached != unsafe { nil } {
		if voidptr(cached.font_size_value) == voidptr(font_size_value)
		&& voidptr(cached.line_height_value) == voidptr(line_height_value)
		&& cached.line_height == c.line_height_
		&& voidptr(cached.font) == voidptr(c.cached_first_available_computed_font_)
		&& cached.root_font_size == c.root_font_size_px_
		&& cached.root_line_height == c.root_line_height_px_ {
			return cached
		}
	}
	// Cached on the style, which outlives any arena its caller works in.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	font_px := CSSPixels.nearest_value_for(c.resolved_font_size_px())
	mut font_metrics := computed_interpolation_font_metrics_for_size(font_px)
	font_metrics.line_height = c.line_height()
	mut root_font_metrics := computed_interpolation_font_metrics_for_size(CSSPixels.nearest_value_for(c.root_font_size_px_))
	root_font_metrics.line_height = CSSPixels.nearest_value_for(c.root_line_height_px_)
	metrics := &ComputedLengthMetrics{
		font_size_value: font_size_value
		line_height_value: line_height_value
		line_height: c.line_height_
		font: c.cached_first_available_computed_font_
		root_font_size: c.root_font_size_px_
		root_line_height: c.root_line_height_px_
		font_metrics: font_metrics
		root_font_metrics: root_font_metrics
	}
	mut mutable := unsafe { &ComputedProperties(c) }
	mutable.cached_length_metrics_ = metrics
	return metrics
}

// Resolve a box-model length/percentage property (margin/padding/border-width/width/height/inset...) from
// THIS computed style to px, for the real layout engine (which holds a css.ComputedProperties, not a DOM
// element). `percentage_basis_px` is the reference for `%` (the containing block's inline size for
// horizontal box-model properties, block size for vertical). Returns none for `auto`, other keywords, and
// unsupported keywords. Viewport and root-font metrics are retained on the
// computed style so Layout resolves them against the same context StyleComputer
// used while computing the element.
pub fn (c &ComputedProperties) length_percentage_to_px(property_id PropertyID, percentage_basis_px f64) ?f64 {
	return computed_properties_length_percentage_to_px(c, property_id, percentage_basis_px)
}

fn (c &ComputedProperties) absolute_layout_length_to_px(length Length) CSSPixels {
	if subject := c.subject_element_ {
		if subject.document().font_rendering_policy() == .chromium {
			return CSSPixels.truncated_value_for(length.absolute_length_to_px_without_rounding())
		}
		return length.absolute_length_to_px()
	}
	if c.cached_first_available_computed_font_ != unsafe { nil }
		&& c.cached_first_available_computed_font_.font_rendering_policy == .chromium {
		return CSSPixels.truncated_value_for(length.absolute_length_to_px_without_rounding())
	}
	return length.absolute_length_to_px()
}

fn computed_properties_length_percentage_to_px(c &ComputedProperties, property_id PropertyID, percentage_basis_px f64) ?f64 {
	value := c.property(property_id, .yes) or { return none }
	typed := style_value_logic_from_dom(property_id, value) or { return none }
	// SVG accepts a unitless <number> for these presentation properties. In
	// user space that number is a CSS pixel, matching SVGLength::value() and
	// Ladybird's computed LengthPercentage representation.
	if typed.is_number() && property_id in [.stroke_width, .stroke_dashoffset] {
		return typed.as_number().number()
	}
	if !typed.is_length() && !typed.is_percentage() && !typed.is_calculated() {
		return none
	}
	// These conversions consume no font, viewport or query-container state.
	// Keep the same fixed-point conversion used by the layout-value accessor.
	if typed is LengthStyleValue {
		length := typed.length()
		if length.is_absolute() {
			return c.absolute_layout_length_to_px(length).to_double()
		}
	} else if typed is PercentageStyleValue {
		return LengthPercentage.from_style_value_logic(typed).to_px(LengthResolutionContext{},
			CSSPixels.nearest_value_for(percentage_basis_px)).to_double()
	}
	context := c.length_resolution_context()
	return LengthPercentage.from_style_value_logic(typed).to_px(context,
		CSSPixels.nearest_value_for(percentage_basis_px)).to_double()
}

// Return the retained computed StyleValue. ComputedProperties stores the same
// typed CSSStyleValue graph as C++; parsing css_text is only a compatibility
// boundary for hand-authored DOM values.
pub fn (c &ComputedProperties) typed_property_value(property_id PropertyID) ?StyleValue {
	value := c.property(property_id, .yes) or { return none }
	return style_value_logic_from_dom(property_id, value)
}

// Resolve a component of a typed composite value (for example a border-radius
// axis or a shadow offset) with this computed style's font/root/viewport
// metrics. This is Length::to_px(Length::ResolutionContext::for_layout_node())
// without a serialize/parse round trip.
pub fn (c &ComputedProperties) resolve_length_percentage_value_px(value StyleValue, percentage_basis_px f64) ?f64 {
	if !value.is_length() && !value.is_percentage() && !value.is_calculated() {
		return none
	}
	if value is LengthStyleValue {
		length := value.length()
		if length.is_absolute() {
			return c.absolute_layout_length_to_px(length).to_double()
		}
	} else if value is PercentageStyleValue {
		return LengthPercentage.from_style_value_logic(value).to_px(LengthResolutionContext{},
			CSSPixels.nearest_value_for(percentage_basis_px)).to_double()
	}
	context := c.length_resolution_context()
	return LengthPercentage.from_style_value_logic(value).to_px(context,
		CSSPixels.nearest_value_for(percentage_basis_px)).to_double()
}

// Length::ResolutionContext::for_layout_node(), using the metrics retained by
// ComputedProperties during StyleComputer::compute_property_values().
pub fn (c &ComputedProperties) length_resolution_context() LengthResolutionContext {
	metrics := c.length_font_metrics()
	mut context := LengthResolutionContext{
		viewport_rect: c.viewport_rect_
		font_metrics: metrics.font_metrics
		root_font_metrics: metrics.root_font_metrics
		font_metrics_depend_on_viewport_metrics: c.font_metrics_depend_on_viewport_metrics()
		root_font_metrics_depend_on_viewport_metrics: c.root_font_metrics_depend_on_viewport_metrics_
	}
	if subject := c.subject_element_ {
		context.subject_element = subject
		context.subject_inline_axis_is_horizontal = c.writing_mode() == .horizontal_tb
		context.query_container_cache = &LengthQueryContainerCache{}
	}
	return context
}

// This computed style's font-size in px (already absolute in a computed style). Falls back to 16px.
pub fn (c &ComputedProperties) resolved_font_size_px() f64 {
	value := c.property(.font_size, .yes) or { return 16.0 }
	typed := style_value_logic_from_dom(.font_size, value) or { return 16.0 }
	if typed.is_length() {
		length := typed.as_length().length()
		if length.is_absolute() {
			return length.absolute_length_to_px_without_rounding()
		}
	}
	return 16.0
}
