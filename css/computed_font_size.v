module css

import dom

// Computed-value resolution for the compatibility cascade API. It uses the
// same typed LengthResolutionContext and font-size mappings as StyleComputer:
// absolute lengths convert directly; em/% resolve against the parent's computed font-size; rem
// against the root element's; the absolute-size keywords use the CSS font-size scale.

const default_font_size_px = 16.0 // the initial value of font-size ('medium')

// Resolve a specified font-size string to computed px, given the parent's and root's computed px.
fn resolve_font_size_px(specified string, parent_px f64, root_px f64, viewport dom.Rect) f64 {
	value := parse_css_value_logic(.font_size, specified) or { return parent_px }
	parent_size := CSSPixels.nearest_value_for(parent_px)
	root_size := CSSPixels.nearest_value_for(root_px)
	context := LengthResolutionContext{
		viewport_rect: CSSPixelRect.new(viewport.x, viewport.y, viewport.width, viewport.height)
		font_metrics: computed_interpolation_font_metrics_for_size(parent_size)
		root_font_metrics: computed_interpolation_font_metrics_for_size(root_size)
	}
	if value is LengthStyleValue {
		length := value.length()
		if length.is_absolute() || length.is_font_relative() || length.is_viewport_relative() {
			return length.to_px(context).to_double()
		}
	}
	if value is PercentageStyleValue {
		return parent_px * value.percentage().as_fraction()
	}
	if value is CalculatedStyleValue {
		resolved := value.resolve_length(CalculationResolutionContext{
			percentage_basis: Length.make_css_px(parent_size)
			length_resolution_context: context
		}) or { return parent_px }
		return resolved.to_px(context).to_double()
	}
	if absolute_size := computed_interpolation_keyword_to_absolute_size(value.to_keyword()) {
		return StyleComputer.absolute_size_mapping(absolute_size, StyleComputer.default_user_font_size()).to_double()
	}
	if relative_size := computed_interpolation_keyword_to_relative_size(value.to_keyword()) {
		return StyleComputer.relative_size_mapping(relative_size, parent_size).to_double()
	}
	return parent_px
}

// The element's own specified font-size (inline + author + UA, NOT inherited), if any.
fn own_font_size(element &dom.Element, author_rules []&CSSRule) ?string {
	return specified_value_on(element, 'font-size', author_rules, user_agent_rules())
}

// The document root element's computed font-size (px), used to resolve rem. The root's reference is
// the initial 16px (it has no parent element).
pub fn root_font_size_px(element &dom.Element, author_rules []&CSSRule) f64 {
	mut root := element
	for {
		parent := root.as_node().parent_element() or { break }
		root = parent
	}
	own := own_font_size(root, author_rules) or { return default_font_size_px }
	return resolve_font_size_px(own, default_font_size_px, default_font_size_px, root.document().viewport_rect())
}

// https://drafts.csswg.org/css-fonts/#font-size-prop
// The computed font-size (px) of `element`: resolve its own specified font-size against its parent's
// computed font-size; if the element has no own font-size, it inherits the parent's computed value.
pub fn computed_font_size_px(element &dom.Element, author_rules []&CSSRule) f64 {
	abstract_element := dom.AbstractElement.new(element, none)
	if dom_computed := abstract_element.computed_properties() {
		if computed := computed_properties_from_dom(dom_computed) {
			return computed.resolved_font_size_px()
		}
	}
	parent_px := if parent := element.as_node().parent_element() {
		computed_font_size_px(parent, author_rules)
	} else {
		default_font_size_px
	}
	own := own_font_size(element, author_rules) or {
		// No own declaration: font-size inherits, so the computed value is the parent's.
		return parent_px
	}
	root_px := if own.contains('rem') {
		root_font_size_px(element, author_rules)
	} else {
		parent_px
	}
	return resolve_font_size_px(own, parent_px, root_px, element.document().viewport_rect())
}
