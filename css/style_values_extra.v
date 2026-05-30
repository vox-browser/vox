// Extra translations for LibWeb/CSS/StyleValues subclasses whose primary V
// definitions already exist in this module.
module css

import math

// These local stand-ins make missing LibWeb DOM/layout/platform dependencies
// explicit at call sites while keeping the translated StyleValue logic usable.
pub struct StyleValueLayoutNodeStub {
pub mut:
	length_resolution_context LengthResolutionContext = LengthResolutionContext.default()
}

pub struct StyleValueImageCursorStub {
pub mut:
	hotspot_x int
	hotspot_y int
}

pub struct StyleValuePathStub {
pub mut:
	commands  []string
	fill_rule FillRule = .nonzero
}

pub struct TreeCountingResolutionContext {
pub mut:
	sibling_count int
	sibling_index int
}

pub struct TreeCountingAbstractElementStub {
pub mut:
	resolution_context                TreeCountingResolutionContext
	style_uses_tree_counting_function bool
}

pub fn (mut element TreeCountingAbstractElementStub) set_style_uses_tree_counting_function() {
	element.style_uses_tree_counting_function = true
}

pub fn (element TreeCountingAbstractElementStub) tree_counting_function_resolution_context() TreeCountingResolutionContext {
	return element.resolution_context
}

pub struct CSSStyleSheetStub {}

fn style_values_extra_length_percentage_from_style_value(style_value StyleValue) LengthPercentage {
	return match style_value {
		LengthStyleValue {
			LengthPercentage.from_length(style_value.length())
		}
		PercentageStyleValue {
			LengthPercentage.from_percentage(style_value.percentage())
		}
		CalculatedStyleValue {
			LengthPercentage.from_calculated(style_value)
		}
		StubStyleValue {
			// Stub: EdgeStyleValue::with_resolved_keywords() currently has to store
			// calc(100% - offset) as a calculated StubStyleValue because the
			// calculation tree is not translated yet.
			if style_value.type_ == .calculated {
				LengthPercentage.from_length(Length.make_px(0))
			} else {
				panic('VERIFY_NOT_REACHED')
			}
		}
		else {
			panic('VERIFY_NOT_REACHED')
		}
	}
}

fn style_values_extra_length_percentage_to_px(style_value StyleValue, context LengthResolutionContext, reference_value CSSPixels) CSSPixels {
	return style_values_extra_length_percentage_from_style_value(style_value).to_px(context,
		reference_value)
}

fn style_values_extra_length_from_style_value(style_value StyleValue) Length {
	return match style_value {
		LengthStyleValue {
			style_value.length()
		}
		CalculatedStyleValue {
			style_value.resolve_length(CalculationResolutionContext{}) or { Length.make_px(0) }
		}
		StubStyleValue {
			// Stub: calculation nodes are not translated enough to resolve this.
			if style_value.type_ == .calculated {
				Length.make_px(0)
			} else {
				panic('VERIFY_NOT_REACHED')
			}
		}
		else {
			panic('VERIFY_NOT_REACHED')
		}
	}
}

fn style_values_extra_angle_from_style_value(style_value StyleValue) Angle {
	return match style_value {
		AngleStyleValue {
			style_value.angle()
		}
		CalculatedStyleValue {
			style_value.resolve_angle(CalculationResolutionContext{}) or { Angle.new(0, .deg) }
		}
		StubStyleValue {
			// Stub: calculation nodes are not translated enough to resolve this.
			if style_value.type_ == .calculated {
				Angle.new(0, .deg)
			} else {
				panic('VERIFY_NOT_REACHED')
			}
		}
		else {
			panic('VERIFY_NOT_REACHED')
		}
	}
}

fn style_values_extra_rect_left(rect CSSPixelRect) CSSPixels {
	return rect.x
}

fn style_values_extra_rect_top(rect CSSPixelRect) CSSPixels {
	return rect.y
}

fn style_values_extra_rect_right(rect CSSPixelRect) CSSPixels {
	return rect.x.plus(rect.width)
}

fn style_values_extra_rect_bottom(rect CSSPixelRect) CSSPixels {
	return rect.y.plus(rect.height)
}

fn style_values_extra_css_abs(value CSSPixels) CSSPixels {
	if value.raw_value() < 0 {
		return CSSPixels.from_raw(-value.raw_value())
	}
	return value
}

fn style_values_extra_css_min(a CSSPixels, b CSSPixels) CSSPixels {
	if a.raw_value() < b.raw_value() {
		return a
	}
	return b
}

fn style_values_extra_css_max(a CSSPixels, b CSSPixels) CSSPixels {
	if a.raw_value() > b.raw_value() {
		return a
	}
	return b
}

fn style_values_extra_css_pixel_sqrt(value f64) CSSPixels {
	return CSSPixels.nearest_value_for(math.sqrt(value))
}

fn style_values_extra_square_distance_between(a CSSPixelPoint, b CSSPixelPoint) f64 {
	x := a.x().to_double() - b.x().to_double()
	y := a.y().to_double() - b.y().to_double()
	return x * x + y * y
}

fn style_values_extra_side_shape(center CSSPixelPoint, reference_box CSSPixelRect, use_farthest bool) CSSPixelSize {
	left_distance :=
		style_values_extra_css_abs(style_values_extra_rect_left(reference_box).minus(center.x()))
	right_distance :=
		style_values_extra_css_abs(style_values_extra_rect_right(reference_box).minus(center.x()))
	top_distance :=
		style_values_extra_css_abs(style_values_extra_rect_top(reference_box).minus(center.y()))
	bottom_distance :=
		style_values_extra_css_abs(style_values_extra_rect_bottom(reference_box).minus(center.y()))

	if use_farthest {
		return CSSPixelSize.new(style_values_extra_css_max(left_distance, right_distance), style_values_extra_css_max(top_distance,
			bottom_distance))
	}

	return CSSPixelSize.new(style_values_extra_css_min(left_distance, right_distance), style_values_extra_css_min(top_distance,
		bottom_distance))
}

fn style_values_extra_closest_side_shape(center CSSPixelPoint, reference_box CSSPixelRect) CSSPixelSize {
	return style_values_extra_side_shape(center, reference_box, false)
}

fn style_values_extra_farthest_side_shape(center CSSPixelPoint, reference_box CSSPixelRect) CSSPixelSize {
	return style_values_extra_side_shape(center, reference_box, true)
}

fn style_values_extra_corner_distance(center CSSPixelPoint, reference_box CSSPixelRect, use_farthest bool) (CSSPixels, CSSPixelPoint) {
	corners := [
		CSSPixelPoint.new(style_values_extra_rect_left(reference_box),
			style_values_extra_rect_top(reference_box)),
		CSSPixelPoint.new(style_values_extra_rect_right(reference_box),
			style_values_extra_rect_top(reference_box)),
		CSSPixelPoint.new(style_values_extra_rect_right(reference_box),
			style_values_extra_rect_bottom(reference_box)),
		CSSPixelPoint.new(style_values_extra_rect_left(reference_box),
			style_values_extra_rect_bottom(reference_box)),
	]

	mut chosen_corner := corners[0]
	mut chosen_distance_squared := style_values_extra_square_distance_between(chosen_corner, center)
	for i := 1; i < corners.len; i++ {
		distance_squared := style_values_extra_square_distance_between(corners[i], center)
		if (use_farthest && distance_squared > chosen_distance_squared)
			|| (!use_farthest && distance_squared < chosen_distance_squared) {
			chosen_corner = corners[i]
			chosen_distance_squared = distance_squared
		}
	}

	return style_values_extra_css_pixel_sqrt(chosen_distance_squared), chosen_corner
}

fn style_values_extra_ellipse_corner_shape(center CSSPixelPoint, reference_box CSSPixelRect, use_farthest bool) CSSPixelSize {
	_, corner := style_values_extra_corner_distance(center, reference_box, use_farthest)
	shape := if use_farthest {
		style_values_extra_farthest_side_shape(center, reference_box)
	} else {
		style_values_extra_closest_side_shape(center, reference_box)
	}

	height := shape.height()
	width := shape.width()
	if height.raw_value() == 0 {
		// https://w3c.github.io/csswg-drafts/css-images/#degenerate-radials
		return CSSPixelSize.new(CSSPixels.nearest_value_for(1.0e9), CSSPixels.from_raw(1))
	}

	aspect_ratio := width.to_double() / height.to_double()
	p_x := corner.x().to_double() - center.x().to_double()
	p_y := corner.y().to_double() - center.y().to_double()
	radius_a := math.sqrt(p_y * p_y * aspect_ratio * aspect_ratio + p_x * p_x)
	radius_b := radius_a / aspect_ratio
	return CSSPixelSize.from_values(radius_a, radius_b)
}

// --- CursorStyleValue extra helpers ---

pub fn (style_value CursorStyleValue) image() CursorImageValue {
	return style_value.image_
}

pub fn (style_value CursorStyleValue) x() ?StyleValue {
	return style_value.x_
}

pub fn (style_value CursorStyleValue) y() ?StyleValue {
	return style_value.y_
}

pub fn (style_value CursorStyleValue) make_image_cursor(node StyleValueLayoutNodeStub) ?StyleValueImageCursorStub {
	_ = node
	_ = style_value
	// Stub: AbstractImageStyleValue, image decoding/painting, platform cursor
	// limits, and embedded cursor hotspots are not translated in this V port.
	return none
}

// --- BasicShapeStyleValue extra helpers ---

pub fn (style_value BasicShapeStyleValue) to_path(reference_box CSSPixelRect, node StyleValueLayoutNodeStub) StyleValuePathStub {
	_ = reference_box
	_ = node
	shape := style_value.basic_shape_
	return match shape {
		BasicShapePolygon {
			mut commands := []string{}
			for index, point in shape.points {
				verb := if index == 0 { 'M' } else { 'L' }
				commands << '${verb} ${point.x.serialize(.normal)} ${point.y.serialize(.normal)}'
			}
			commands << 'Z'
			StyleValuePathStub{
				commands:  commands
				fill_rule: shape.fill_rule
			}
		}
		BasicShapePath {
			StyleValuePathStub{
				commands:  [shape.path_instructions]
				fill_rule: shape.fill_rule
			}
		}
		else {
			// Stub: Gfx::Path, Painting::BorderRadiiData, and Layout::Node
			// geometry are not translated. Serialization preserves the source
			// shape until those dependencies exist.
			StyleValuePathStub{
				commands: [style_value.serialize(.normal)]
			}
		}
	}
}

// --- FilterValueListStyleValue extra helpers ---

pub fn (blur FilterOperationBlur) resolved_radius() f64 {
	return style_values_extra_length_from_style_value(blur.radius).absolute_length_to_px_without_rounding()
}

pub fn (blur FilterOperationBlur) resolved_radius_with_context(context LengthResolutionContext) f64 {
	return style_values_extra_length_from_style_value(blur.radius).to_px_without_rounding(context)
}

pub fn (hue_rotate FilterOperationHueRotate) angle_degrees() f64 {
	return style_values_extra_angle_from_style_value(hue_rotate.angle).to_degrees()
}

pub fn (color FilterOperationColor) resolved_amount() f64 {
	return number_from_style_value(color.amount, 1.0)
}

// --- PositionStyleValue / RadialSizeStyleValue extra helpers ---

pub fn (style_value PositionStyleValue) resolved(node StyleValueLayoutNodeStub, rect CSSPixelRect) CSSPixelPoint {
	// Note: A preset + a none default x/y_relative_to is impossible in the syntax and makes little sense.
	x := style_values_extra_length_percentage_to_px(style_value.edge_x_.offset(),
		node.length_resolution_context, rect.width)
	y := style_values_extra_length_percentage_to_px(style_value.edge_y_.offset(),
		node.length_resolution_context, rect.height)
	return CSSPixelPoint.new(rect.x.plus(x), rect.y.plus(y))
}

pub fn (style_value RadialSizeStyleValue) resolve_circle_size(center CSSPixelPoint, reference_box CSSPixelRect, node StyleValueLayoutNodeStub) CSSPixels {
	if style_value.components_.len != 1 {
		panic('VERIFY_NOT_REACHED')
	}

	component := style_value.components_[0]
	mut resolved_size := CSSPixels.new(0)
	match component {
		RadialExtentComponent {
			resolved_size = match component.extent {
				.closest_side {
					side_distances := style_values_extra_closest_side_shape(center, reference_box)
					style_values_extra_css_min(side_distances.width(), side_distances.height())
				}
				.farthest_side {
					side_distances := style_values_extra_farthest_side_shape(center, reference_box)
					style_values_extra_css_max(side_distances.width(), side_distances.height())
				}
				.closest_corner {
					distance, _ := style_values_extra_corner_distance(center, reference_box, false)
					distance
				}
				.farthest_corner {
					distance, _ := style_values_extra_corner_distance(center, reference_box, true)
					distance
				}
			}
		}
		StyleValue {
			radius_ref := math.sqrt(
				reference_box.width.to_double() * reference_box.width.to_double() +
				reference_box.height.to_double() * reference_box.height.to_double()) / math.sqrt(2.0)
			resolved := style_values_extra_length_percentage_to_px(component,
				node.length_resolution_context, CSSPixels.nearest_value_for(radius_ref))
			resolved_size = CSSPixels.nearest_value_for(math.max(0.0, resolved.to_double()))
		}
	}

	// https://w3c.github.io/csswg-drafts/css-images/#degenerate-radials
	// If the ending shape is a circle with zero radius, render as if it
	// were a circle with an arbitrary very small radius greater than zero.
	if resolved_size.raw_value() == 0 {
		return CSSPixels.from_raw(1)
	}

	return resolved_size
}

pub fn (style_value RadialSizeStyleValue) resolve_ellipse_size(center CSSPixelPoint, reference_box CSSPixelRect, node StyleValueLayoutNodeStub) CSSPixelSize {
	if style_value.components_.len != 1 && style_value.components_.len != 2 {
		panic('VERIFY_NOT_REACHED')
	}

	first_size := style_value.resolve_ellipse_component(style_value.components_[0], center,
		reference_box, node, reference_box.width)
	second_component := if style_value.components_.len == 1 {
		style_value.components_[0]
	} else {
		style_value.components_[1]
	}
	second_size := style_value.resolve_ellipse_component(second_component, center, reference_box,
		node, reference_box.height)
	mut resolved_size := CSSPixelSize.new(first_size.width(), second_size.height())

	// Handle degenerate cases from CSS Images.
	if resolved_size.width().raw_value() <= 0 {
		return CSSPixelSize.new(CSSPixels.from_raw(1), CSSPixels.nearest_value_for(1.0e9))
	}
	if resolved_size.height().raw_value() <= 0 {
		return CSSPixelSize.new(CSSPixels.nearest_value_for(1.0e9), CSSPixels.from_raw(1))
	}
	return resolved_size
}

fn (style_value RadialSizeStyleValue) resolve_ellipse_component(component RadialSizeStyleValueComponent, center CSSPixelPoint, reference_box CSSPixelRect, node StyleValueLayoutNodeStub, reference_size CSSPixels) CSSPixelSize {
	_ = style_value
	return match component {
		RadialExtentComponent {
			match component.extent {
				.closest_side { style_values_extra_closest_side_shape(center, reference_box) }
				.farthest_side { style_values_extra_farthest_side_shape(center, reference_box) }
				.closest_corner { style_values_extra_ellipse_corner_shape(center, reference_box,
						false) }
				.farthest_corner { style_values_extra_ellipse_corner_shape(center, reference_box,
						true) }
			}
		}
		StyleValue {
			value := style_values_extra_length_percentage_to_px(component,
				node.length_resolution_context, reference_size)
			CSSPixelSize.new(value, value)
		}
	}
}

// --- RandomValueSharingStyleValue extra helpers ---

pub fn (style_value RandomValueSharingStyleValue) is_fixed() bool {
	return style_value.fixed_value_ != none
}

pub fn (style_value RandomValueSharingStyleValue) is_auto() bool {
	return style_value.is_auto_
}

pub fn (style_value RandomValueSharingStyleValue) name() ?string {
	return style_value.name_
}

pub fn (style_value RandomValueSharingStyleValue) element_shared() bool {
	return style_value.element_shared_
}

pub fn (style_value RandomValueSharingStyleValue) random_caching_key(element_id ?i64) ?RandomCachingKey {
	if style_value.fixed_value_ != none {
		return none
	}
	name := style_value.name_ or { return none }
	return RandomCachingKey{
		name:       name
		element_id: if style_value.element_shared_ { none } else { element_id }
	}
}

// --- ShorthandStyleValue extra helpers ---

pub fn (style_value ShorthandStyleValue) longhand(longhand PropertyID) ?StyleValue {
	for i, sub_property in style_value.sub_properties_ {
		if sub_property == longhand {
			return style_value.values_[i]
		}
	}
	return none
}

pub fn (style_value ShorthandStyleValue) set_style_sheet(style_sheet CSSStyleSheetStub) {
	_ = style_value
	_ = style_sheet
	// Stub: CSSStyleSheet ownership propagation is not represented on V StyleValue objects yet.
}

// --- StyleValueList extra helpers ---

pub fn (style_value StyleValueList) subdivide_into_iterations(property PropertyNameAndID) StyleValueVector {
	// To subdivide into iterations a CSS value whole value for a property property:
	// 1. If property is a single-valued property, return a list containing whole value.
	if property.is_custom_property() {
		return [StyleValue(style_value)]
	}
	property_id := property.id() or { return [StyleValue(style_value)] }
	if !property_is_list_valued(property_id) {
		return [StyleValue(style_value)]
	}

	// 2. Otherwise, divide whole value into individual iterations, as appropriate for property, and return a list
	//    containing the iterations in order.
	return style_value.values_
}

pub fn (style_value StyleValueList) set_style_sheet(style_sheet CSSStyleSheetStub) {
	_ = style_value
	_ = style_sheet
	// Stub: CSSStyleSheet ownership propagation is not represented on V StyleValue objects yet.
}

// --- TreeCountingFunctionStyleValue extra helpers ---

pub fn (style_value TreeCountingFunctionStyleValue) function() TreeCountingFunction {
	return style_value.function_
}

pub fn (style_value TreeCountingFunctionStyleValue) computed_type() TreeCountingComputedType {
	return style_value.computed_type_
}

pub fn (style_value TreeCountingFunctionStyleValue) resolve_for_element(mut abstract_element TreeCountingAbstractElementStub) int {
	abstract_element.set_style_uses_tree_counting_function()
	context := abstract_element.tree_counting_function_resolution_context()
	return style_value.resolve_for_context(context)
}

pub fn (style_value TreeCountingFunctionStyleValue) resolve_for_context(context TreeCountingResolutionContext) int {
	return match style_value.function_ {
		.sibling_count { context.sibling_count }
		.sibling_index { context.sibling_index }
	}
}

pub fn (style_value TreeCountingFunctionStyleValue) resolve_to_calculation_node(calculation_context CalculationContext, resolution_context ?TreeCountingResolutionContext) ?CalculationNode {
	_ = calculation_context
	context := resolution_context or { return none }
	return CalculationNode{
		serialization: '${style_value.resolve_for_context(context)}'
	}
}

// --- UnresolvedStyleValue extra helpers ---

pub fn (style_value UnresolvedStyleValue) values() []ComponentValue {
	return style_value.tokens
}

pub fn (style_value UnresolvedStyleValue) tokenize() []ComponentValue {
	return style_value.tokens
}

pub fn (style_value UnresolvedStyleValue) substitution_functions_presence() SubstitutionFunctionsPresence {
	mut presence := SubstitutionFunctionsPresence{}
	for component_value in style_value.tokens {
		if component_value.is_function() {
			component_value.function().contains_arbitrary_substitution_function(mut presence)
		}
		if component_value.is_block() {
			component_value.block().contains_arbitrary_substitution_function(mut presence)
		}
	}
	return presence
}

pub fn (style_value UnresolvedStyleValue) contains_arbitrary_substitution_function() bool {
	return style_value.substitution_functions_presence().has_any()
}

pub fn (style_value UnresolvedStyleValue) includes_attr_function() bool {
	return style_value.substitution_functions_presence().attr
}

pub fn (style_value UnresolvedStyleValue) includes_inherit_function() bool {
	return style_value.substitution_functions_presence().inherit
}

pub fn (style_value UnresolvedStyleValue) includes_if_function() bool {
	return style_value.substitution_functions_presence().if_
}

pub fn (style_value UnresolvedStyleValue) includes_var_function() bool {
	return style_value.substitution_functions_presence().var
}

pub fn (style_value UnresolvedStyleValue) includes_env_function() bool {
	return style_value.substitution_functions_presence().env
}
