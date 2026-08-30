module css

import dom

// Resolve `property_id`'s cascaded value to absolute px for `element`, when it is a length. This
// feeds real pixel numbers to layout: absolute lengths convert directly; em/ex/ch resolve against
// the element's computed font-size; rem against the root element's font-size.
//
// Returns none for values that can't be resolved to px here: percentages (they need a
// containing-block basis that only layout has), keywords like 'auto', calc(), and viewport units.
//
// NOTE: correct for non-inherited length properties (width/height/margin/padding/border-width/insets
// — the common layout inputs). FIXME: for the few INHERITED length properties (letter-spacing,
// line-height, ...) a relative unit inherited from an ancestor is resolved against this element's
// font-size rather than the ancestor's.
pub fn computed_length_px(element &dom.Element, property_id PropertyID, author_rules []&CSSRule) ?f64 {
	specified := cascaded_value_with_ua(element, property_id, author_rules)
	value := parse_css_value_logic(property_id, specified) or { return none }
	if !value.is_length() {
		// A calc() that resolves without a percentage basis (e.g. calc(50px + 2em)) is absolute here;
		// a calc() needing a percentage is left to layout (which has the containing basis).
		if value.is_calculated() {
			context := calc_resolution_context(element, none, author_rules)
			if length := value.as_calculated().resolve_length(context) {
				return length.to_px(context.length_resolution_context).to_double()
			}
		}
		return none
	}
	length := value.as_length().length()
	context := calc_resolution_context(element, none, author_rules).length_resolution_context
	if length.is_absolute() || length.is_font_relative() || length.is_viewport_relative() {
		return length.to_px(context).to_double()
	}
	return none
}

// Resolve a box-model length/percentage property (margin/padding/border-width/width/height/inset...) from
// THIS computed style to px, for the real layout engine (which holds a css.ComputedProperties, not a DOM
// element). `percentage_basis_px` is the reference for `%` (the containing block's inline size for
// horizontal box-model properties, block size for vertical). Returns none for `auto`, other keywords, and
// unsupported keywords. Viewport and root-font metrics are retained on the
// computed style so Layout resolves them against the same context StyleComputer
// used while computing the element.
pub fn (c &ComputedProperties) length_percentage_to_px(property_id PropertyID, percentage_basis_px f64) ?f64 {
	value := c.property(property_id, .yes) or { return none }
	typed := parse_css_value_logic(property_id, value.css_text) or { return none }
	if typed.is_percentage() {
		percentage := typed.as_percentage().percentage()
		basis := CSSPixels.nearest_value_for(percentage_basis_px)
		numerator := CSSPixels.nearest_value_for(percentage.value() * basis.to_double())
		return numerator.divided_by(CSSPixels.new(100)).to_css_pixels().to_double()
	}
	// SVG accepts a unitless <number> for these presentation properties. In
	// user space that number is a CSS pixel, matching SVGLength::value() and
	// Ladybird's computed LengthPercentage representation.
	if typed.is_number() && property_id in [.stroke_width, .stroke_dashoffset] {
		return typed.as_number().number()
	}
	font_px := CSSPixels.nearest_value_for(c.resolved_font_size_px())
	root_font_px := CSSPixels.nearest_value_for(c.root_font_size_px_)
	mut context := LengthResolutionContext.default()
	context.viewport_rect = c.viewport_rect_
	context.font_metrics = computed_interpolation_font_metrics_for_size(font_px)
	context.font_metrics.line_height = c.line_height()
	context.root_font_metrics = computed_interpolation_font_metrics_for_size(root_font_px)
	context.root_font_metrics.line_height = CSSPixels.nearest_value_for(c.root_line_height_px_)
	if typed.is_calculated() {
		resolution_context := CalculationResolutionContext{
			percentage_basis:          Length.make_px(percentage_basis_px)
			length_resolution_context: context
		}
		if length := typed.as_calculated().resolve_length(resolution_context) {
			return length.to_px(context).to_double()
		}
		return none
	}
	if !typed.is_length() {
		return none
	}
	length := typed.as_length().length()
	if length.is_absolute() {
		return length.absolute_length_to_px().to_double()
	}
	if length.is_viewport_relative() {
		return length.viewport_relative_length_to_px(c.viewport_rect_).to_double()
	}
	return length.to_px(context).to_double()
}

// This computed style's font-size in px (already absolute in a computed style). Falls back to 16px.
pub fn (c &ComputedProperties) resolved_font_size_px() f64 {
	value := c.property(.font_size, .yes) or { return 16.0 }
	typed := parse_css_value_logic(.font_size, value.css_text) or { return 16.0 }
	if typed.is_length() {
		length := typed.as_length().length()
		if length.is_absolute() {
			return length.absolute_length_to_px().to_double()
		}
	}
	return 16.0
}

// The percentage value of `property_id`'s cascaded value (e.g. 50.0 for `50%`), or none when the
// value isn't a percentage. Layout resolves this against the relevant containing-block basis (a
// percentage width against the containing block's width, etc.).
pub fn computed_percentage(element &dom.Element, property_id PropertyID, author_rules []&CSSRule) ?f64 {
	specified := cascaded_value_with_ua(element, property_id, author_rules)
	value := parse_css_value_logic(property_id, specified) or { return none }
	if !value.is_percentage() {
		return none
	}
	return value.as_percentage().percentage().value()
}

// A calc() resolution context using `element`'s computed font-size (for em/ex/ch), the root font-size
// (for rem), and an optional percentage basis in px (the containing measure for `%` inside the calc).
fn calc_resolution_context(element &dom.Element, percentage_basis_px ?f64, author_rules []&CSSRule) CalculationResolutionContext {
	font_metrics := computed_interpolation_font_metrics_for_size(CSSPixels.nearest_value_for(computed_font_size_px(element,
		author_rules)))
	root_font_metrics := computed_interpolation_font_metrics_for_size(CSSPixels.nearest_value_for(root_font_size_px(element,
		author_rules)))
	mut length_context := LengthResolutionContext.default()
	length_context.viewport_rect = css_pixel_rect_from_dom_rect(element.document().viewport_rect())
	length_context.font_metrics = font_metrics
	length_context.root_font_metrics = root_font_metrics
	mut context := CalculationResolutionContext{
		length_resolution_context: length_context
	}
	if basis := percentage_basis_px {
		context.percentage_basis = CalculationPercentageBasis(Length.make_px(basis))
	}
	return context
}

// Resolve `property_id`'s cascaded value to px when it is a calc() expression, resolving any `%`
// inside it against `percentage_basis_px` (e.g. the containing width for a width calc). Returns none
// when the value isn't a calc() or doesn't resolve to a length.
pub fn computed_calc_px(element &dom.Element, property_id PropertyID, percentage_basis_px f64, author_rules []&CSSRule) ?f64 {
	specified := cascaded_value_with_ua(element, property_id, author_rules)
	value := parse_css_value_logic(property_id, specified) or { return none }
	if !value.is_calculated() {
		return none
	}
	context := calc_resolution_context(element, percentage_basis_px, author_rules)
	length := value.as_calculated().resolve_length(context) or { return none }
	return length.to_px(context.length_resolution_context).to_double()
}

// Resolve a standalone <length-percentage> token with the same font, root-font, viewport, and
// percentage context used for computed properties. Layout uses this for components embedded inside
// composite values such as transforms, radii, gradients, and grid track functions.
pub fn resolve_length_percentage_text_px(element &dom.Element, text string, percentage_basis_px f64, author_rules []&CSSRule) ?f64 {
	// margin-left accepts the full <length-percentage> grammar, including negative values, without
	// adding property-specific keywords or non-negative clamping.
	value := parse_css_value_logic(.margin_left, text.trim_space()) or { return none }
	context := calc_resolution_context(element, percentage_basis_px, author_rules)
	if value.is_percentage() {
		return percentage_basis_px * value.as_percentage().percentage().value() / 100.0
	}
	if value.is_length() {
		return value.as_length().length().to_px(context.length_resolution_context).to_double()
	}
	if value.is_calculated() {
		length := value.as_calculated().resolve_length(context) or { return none }
		return length.to_px(context.length_resolution_context).to_double()
	}
	return none
}
