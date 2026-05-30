module css

import dom
import strings

// Extra low-level CSS primitive/layout helpers translated from the small LibWeb/CSS
// primitive .cpp files. The core types live in css.v, misc_values.v, url_system.v,
// and value_type_color.v; keep this file to missing helpers and explicit stubs.

fn css_pixel_rect_from_dom_rect(rect dom.Rect) CSSPixelRect {
	return CSSPixelRect.new(rect.x, rect.y, rect.width, rect.height)
}

fn length_resolution_context_from_viewport_rect(viewport_rect CSSPixelRect) LengthResolutionContext {
	font_metrics := LengthFontMetrics.default()
	return LengthResolutionContext{
		viewport_rect:     viewport_rect
		font_metrics:      font_metrics
		root_font_metrics: font_metrics
	}
}

fn length_resolution_context_from_document(document &dom.Document) LengthResolutionContext {
	// Translates Length::ResolutionContext::for_document(). The C++ version gets
	// the initial font and font metrics from Document::font_computer(); those
	// hooks are not available in the V DOM yet, so default initial metrics are
	// the current boundary and the document viewport is preserved.
	return length_resolution_context_from_viewport_rect(css_pixel_rect_from_dom_rect(document.viewport_rect()))
}

fn length_resolution_context_from_layout_node(layout_node &dom.LayoutNode) ?LengthResolutionContext {
	// Translates the document/viewport half of
	// Length::ResolutionContext::for_layout_node(). The V LayoutNode stub does
	// not expose computed_values(), first_available_font(), navigable(), or the
	// root layout node yet. When a DOM back-pointer exists, use its document
	// viewport and keep font metrics at the explicit default-font boundary.
	dom_node := layout_node.dom_node() or { return none }
	return length_resolution_context_from_document(dom_node.document())
}

fn document_from_layout_node(layout_node &dom.LayoutNode) ?&dom.Document {
	dom_node := layout_node.dom_node() or { return none }
	return dom_node.document()
}

// Translates Length::ResolutionContext::for_element(). The C++ version reads
// computed fonts from DOM/Layout; the V DOM style/layout objects do not expose
// those metrics yet, so this uses the element document viewport with default
// font metrics.
pub fn LengthResolutionContext.for_element(element &dom.AbstractElement) LengthResolutionContext {
	return length_resolution_context_from_document(element.document())
}

// Translates Length::ResolutionContext::for_window(). The current Window stub
// can be created without an associated document, so fall back to the default
// zero viewport in that case.
pub fn LengthResolutionContext.for_window(window &dom.Window) LengthResolutionContext {
	document := window.associated_document() or { return LengthResolutionContext.default() }
	return length_resolution_context_from_document(document)
}

// Translates Length::to_px_slow_case(Layout::Node const&). Layout::Node does not
// currently expose computed_values(), first_available_font(), navigable(), or
// root layout nodes in the V port; those font/layout metrics remain an explicit
// boundary, but the C++ branch behavior and document viewport lookup are kept
// when the stub can expose a DOM node.
pub fn (length Length) to_px_slow_case_for_layout_node(layout_node &dom.LayoutNode) CSSPixels {
	if length.is_absolute() {
		return length.absolute_length_to_px()
	}
	document := document_from_layout_node(layout_node) or { return CSSPixels{} }
	if document.get_browsing_context() == none {
		return CSSPixels{}
	}
	context := length_resolution_context_from_document(document)
	if length.is_font_relative() {
		return length.font_relative_length_to_px(context.font_metrics, context.root_font_metrics)
	}
	if length.is_viewport_relative() {
		return length.viewport_relative_length_to_px(context.viewport_rect)
	}
	panic('VERIFY_NOT_REACHED')
}

// StyleValue-backed equivalents of Angle::from_style_value(),
// Length::from_style_value(), and Time::from_style_value(). The existing
// dom.StyleValue entry points are opaque stubs, while the translated parser and
// style value layer use the css.StyleValue sum type.
pub fn Angle.from_style_value(style_value StyleValue, percentage_basis ?Angle) Angle {
	return match style_value {
		AngleStyleValue {
			style_value.angle()
		}
		CalculatedStyleValue {
			style_value.resolve_angle(CalculationResolutionContext{}) or { Angle.make_degrees(0) }
		}
		PercentageStyleValue {
			basis := percentage_basis or { panic('VERIFY_NOT_REACHED') }
			basis.percentage_of(style_value.percentage())
		}
		else {
			panic('VERIFY_NOT_REACHED')
		}
	}
}

pub fn Angle.resolve_calculated_with_context(calculated CalculatedStyleValue, context LengthResolutionContext, reference_value Angle) Angle {
	// CalculationResolutionContext in the V port currently only stores a length
	// percentage basis, so the angle basis cannot be represented yet.
	_ = reference_value
	return calculated.resolve_angle(CalculationResolutionContext{
		length_resolution_context: context
	}) or { Angle.make_degrees(0) }
}

pub fn Frequency.resolve_calculated_with_context(calculated CalculatedStyleValue, context LengthResolutionContext, reference_value Frequency) Frequency {
	// CalculationResolutionContext in the V port currently only stores a length
	// percentage basis, so the frequency basis cannot be represented yet.
	_ = reference_value
	return calculated.resolve_frequency(CalculationResolutionContext{
		length_resolution_context: context
	}) or { Frequency.make_hertz(0) }
}

pub fn Length.from_style_value_logic(style_value StyleValue, percentage_basis ?Length) Length {
	return match style_value {
		LengthStyleValue {
			style_value.length()
		}
		CalculatedStyleValue {
			mut context := CalculationResolutionContext{}
			if basis := percentage_basis {
				context.percentage_basis = basis
			}
			style_value.resolve_length(context) or { Length.make_px(0) }
		}
		PercentageStyleValue {
			basis := percentage_basis or { panic('VERIFY_NOT_REACHED') }
			basis.percentage_of(style_value.percentage())
		}
		else {
			panic('VERIFY_NOT_REACHED')
		}
	}
}

pub fn Time.from_style_value(style_value StyleValue, percentage_basis ?Time) Time {
	return match style_value {
		TimeStyleValue {
			style_value.time()
		}
		CalculatedStyleValue {
			style_value.resolve_time(CalculationResolutionContext{}) or { Time.make_seconds(0) }
		}
		PercentageStyleValue {
			basis := percentage_basis or { panic('VERIFY_NOT_REACHED') }
			basis.percentage_of(style_value.percentage())
		}
		else {
			panic('VERIFY_NOT_REACHED')
		}
	}
}

pub fn Time.resolve_calculated_with_context(calculated CalculatedStyleValue, context LengthResolutionContext, reference_value Time) Time {
	// CalculationResolutionContext in the V port currently only stores a length
	// percentage basis, so the time basis cannot be represented yet.
	_ = reference_value
	return calculated.resolve_time(CalculationResolutionContext{
		length_resolution_context: context
	}) or { Time.make_seconds(0) }
}

pub fn LengthPercentage.from_style_value_logic(style_value StyleValue) LengthPercentage {
	return match style_value {
		LengthStyleValue { LengthPercentage.from_length(style_value.length()) }
		PercentageStyleValue { LengthPercentage.from_percentage(style_value.percentage()) }
		CalculatedStyleValue { LengthPercentage.from_calculated(style_value) }
		else { panic('VERIFY_NOT_REACHED') }
	}
}

pub fn LengthPercentageOrAuto.from_style_value_logic(style_value StyleValue) LengthPercentageOrAuto {
	return LengthPercentageOrAuto.from_length_percentage(LengthPercentage.from_style_value_logic(style_value))
}

pub fn (edge_rect EdgeRect) resolved_for_layout_node(layout_node &dom.LayoutNode, border_box CSSPixelRect) CSSPixelRect {
	// Direct translation of EdgeRect::resolved(Layout::Node const&,
	// CSSPixelRect): each non-auto edge resolves through Length::to_px(node),
	// whose missing font/layout hooks are isolated in to_px_slow_case_for_layout_node().
	left := border_box.x.plus(if length := edge_rect.left_edge.length() {
		length.to_px_slow_case_for_layout_node(layout_node)
	} else {
		CSSPixels{}
	})
	top := border_box.y.plus(if length := edge_rect.top_edge.length() {
		length.to_px_slow_case_for_layout_node(layout_node)
	} else {
		CSSPixels{}
	})
	right := border_box.x.plus(if length := edge_rect.right_edge.length() {
		length.to_px_slow_case_for_layout_node(layout_node)
	} else {
		border_box.width
	})
	bottom := border_box.y.plus(if length := edge_rect.bottom_edge.length() {
		length.to_px_slow_case_for_layout_node(layout_node)
	} else {
		border_box.height
	})
	return CSSPixelRect{
		x:      left
		y:      top
		width:  right.minus(left)
		height: bottom.minus(top)
	}
}

pub fn (size Size) to_px_for_layout_node(layout_node &dom.LayoutNode, reference_value CSSPixels) CSSPixels {
	// Direct translation of Size::to_px(Layout::Node const&, CSSPixels): no
	// length percentage means zero; otherwise resolve against the reference and
	// convert the resulting Length through the layout-node slow path.
	length_percentage := size.length_percentage_ or { return CSSPixels{} }
	context := length_resolution_context_from_layout_node(layout_node) or {
		LengthResolutionContext.default()
	}
	return length_percentage.resolved(context, reference_value).to_px_slow_case_for_layout_node(layout_node)
}

// Ratio::operator== compares the numeric ratio value rather than the raw
// numerator/denominator pair.
pub fn (ratio Ratio) equals(other Ratio) bool {
	return ratio.value() == other.value()
}

pub fn (value_type ValueType) str() string {
	return value_type_to_string(value_type)
}

pub fn (value CrossOriginModifierValue) str() string {
	return value.to_string()
}

pub fn (value ReferrerPolicyModifierValue) str() string {
	return value.to_string()
}

pub fn (modifier RequestURLModifier) str() string {
	return modifier.to_string()
}

pub fn (url URL) str() string {
	return url.to_string()
}

pub fn (url URL) type_() URLType {
	return url.type_
}

pub fn filter_values_from_style_value(style_value StyleValue) []FilterStyleValue {
	if style_value is FilterValueListStyleValue {
		return style_value.filter_value_list()
	}
	return []FilterStyleValue{}
}

pub fn escape_a_character(character u32) string {
	return '\\${rune(character)}'
}

pub fn escape_a_character_as_code_point(character u32) string {
	return '\\${character:x} '
}

pub fn serialize_a_comma_separated_string_list(items []string) string {
	// https://www.w3.org/TR/cssom/#serialize-a-comma-separated-list
	return items.join(', ')
}

fn component_value_token_type_is_one_of(token_type TokenType, values []TokenType) bool {
	return token_type in values
}

fn component_values_need_comment_between(first ComponentValue, second ComponentValue) bool {
	// https://drafts.csswg.org/css-syntax/#serialization
	if first.is(.ident) {
		if second.is_function() {
			return true
		}
		// NB: ( may also be part of a block.
		if second.is_block() && second.block().is_paren() {
			return true
		}
		if !second.is_token() {
			return false
		}
		if second.token().token_type() == .delim {
			return second.is_delim(u32(`-`)) || second.is_delim(u32(`(`))
		}
		return component_value_token_type_is_one_of(second.token().token_type(), [
			TokenType.ident,
			.url,
			.bad_url,
			.number,
			.percentage,
			.dimension,
			.cdc,
		])
	}

	if first.is(.at_keyword) || first.is(.hash) || first.is(.dimension) || first.is_delim(u32(`#`))
		|| first.is_delim(u32(`-`)) {
		if second.is_function() {
			return true
		}
		if !second.is_token() {
			return false
		}
		if second.token().token_type() == .delim {
			return second.token().delim() == `-`
		}
		return component_value_token_type_is_one_of(second.token().token_type(), [
			TokenType.ident,
			.url,
			.bad_url,
			.number,
			.percentage,
			.dimension,
			.cdc,
		])
	}

	if first.is(.number) {
		if second.is_function() {
			return true
		}
		if !second.is_token() {
			return false
		}
		if second.token().token_type() == .delim {
			return second.token().delim() == `%`
		}
		return component_value_token_type_is_one_of(second.token().token_type(), [
			TokenType.ident,
			.url,
			.bad_url,
			.number,
			.percentage,
			.dimension,
			.cdc,
		])
	}

	if first.is_delim(u32(`@`)) {
		if second.is_function() {
			return true
		}
		if !second.is_token() {
			return false
		}
		if second.token().token_type() == .delim {
			return second.token().delim() == `-`
		}
		return component_value_token_type_is_one_of(second.token().token_type(), [
			TokenType.ident,
			.url,
			.bad_url,
			.cdc,
		])
	}

	if first.is_delim(u32(`.`)) || first.is_delim(u32(`+`)) {
		return second.is(.number) || second.is(.percentage) || second.is(.dimension)
	}

	if first.is_delim(u32(`/`)) {
		return second.is_delim(u32(`*`))
	}

	return false
}

pub fn serialize_a_series_of_component_values(component_values []ComponentValue) string {
	// https://drafts.csswg.org/css-syntax/#serialization
	mut builder := strings.new_builder(component_values.len * 8)
	eof := ComponentValue.from_token(Tokenizer.create_eof_token())
	for index, current_token in component_values {
		next_token := if index + 1 < component_values.len {
			component_values[index + 1]
		} else {
			eof
		}
		builder.write_string(current_token.to_string())
		if component_values_need_comment_between(current_token, next_token) {
			builder.write_string('/**/')
		}
	}
	return builder.str()
}

pub fn serialize_a_positional_value_list_2_or_4(values []StyleValue, mode SerializationMode) string {
	match values.len {
		2 {
			first_property_serialized := values[0].to_string_with_mode(mode)
			second_property_serialized := values[1].to_string_with_mode(mode)
			if first_property_serialized == second_property_serialized {
				return first_property_serialized
			}
			return '${first_property_serialized} ${second_property_serialized}'
		}
		4 {
			first_property_serialized := values[0].to_string_with_mode(mode)
			second_property_serialized := values[1].to_string_with_mode(mode)
			third_property_serialized := values[2].to_string_with_mode(mode)
			fourth_property_serialized := values[3].to_string_with_mode(mode)

			if first_property_serialized == second_property_serialized
				&& first_property_serialized == third_property_serialized
				&& first_property_serialized == fourth_property_serialized {
				return first_property_serialized
			}

			if first_property_serialized == third_property_serialized
				&& second_property_serialized == fourth_property_serialized {
				return '${first_property_serialized} ${second_property_serialized}'
			}

			if second_property_serialized == fourth_property_serialized {
				return '${first_property_serialized} ${second_property_serialized} ${third_property_serialized}'
			}

			return '${first_property_serialized} ${second_property_serialized} ${third_property_serialized} ${fourth_property_serialized}'
		}
		else {
			panic('VERIFY_NOT_REACHED')
		}
	}
}
