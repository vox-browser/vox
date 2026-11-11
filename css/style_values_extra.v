// Extra translations for LibWeb/CSS/StyleValues subclasses whose primary V
// definitions already exist in this module.
module css

import dom
import math

// Typed path commands form the CSS-side equivalent of the Gfx::Path built by
// BasicShapeStyleValue.cpp. Painting can consume these without parsing strings.
pub enum StyleValuePathCommandType {
	move_to
	line_to
	elliptical_arc_to
	close
	svg_path
}

pub struct StyleValuePathCommand {
pub mut:
	type_      StyleValuePathCommandType
	point      CSSPixelPoint
	radii      CSSPixelSize
	rotation   f64
	large_arc  bool
	sweep      bool
	svg_source string
}

pub struct StyleValuePath {
pub mut:
	commands  []StyleValuePathCommand
	fill_rule FillRule = .nonzero
}

// Painting turns this typed cursor description into the platform bitmap. It
// carries the same concrete size and hotspot selected by CursorStyleValue.cpp.
pub struct StyleValueImageCursor {
pub:
	image     CSSImageSourceStyleValue
	size      CSSPixelSize
	hotspot_x int
	hotspot_y int
}

fn style_values_extra_move_to(point CSSPixelPoint) StyleValuePathCommand {
	return StyleValuePathCommand{ type_: .move_to, point: point }
}

fn style_values_extra_line_to(point CSSPixelPoint) StyleValuePathCommand {
	return StyleValuePathCommand{ type_: .line_to, point: point }
}

fn style_values_extra_elliptical_arc_to(point CSSPixelPoint, radii CSSPixelSize, large_arc bool, sweep bool) StyleValuePathCommand {
	return StyleValuePathCommand{
		type_: .elliptical_arc_to
		point: point
		radii: radii
		large_arc: large_arc
		sweep: sweep
	}
}

fn style_values_extra_close_path() StyleValuePathCommand {
	return StyleValuePathCommand{ type_: .close }
}

fn style_values_extra_svg_path(source string) StyleValuePathCommand {
	return StyleValuePathCommand{ type_: .svg_path, svg_source: source }
}

fn style_values_extra_length_context(node &dom.LayoutNode) LengthResolutionContext {
	return length_resolution_context_from_layout_node(node) or { LengthResolutionContext.default() }
}

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
		else {
			panic('VERIFY_NOT_REACHED')
		}
	}
}

fn style_values_extra_length_percentage_to_px(style_value StyleValue, context LengthResolutionContext, reference_value CSSPixels) CSSPixels {
	return style_values_extra_length_percentage_from_style_value(style_value).to_px(context, reference_value)
}

fn style_values_extra_length_from_style_value(style_value StyleValue) Length {
	return match style_value {
		LengthStyleValue {
			style_value.length()
		}
		CalculatedStyleValue {
			style_value.resolve_length(CalculationResolutionContext{}) or { Length.make_px(0) }
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
		return CSSPixelSize.new(style_values_extra_css_max(left_distance, right_distance), style_values_extra_css_max(top_distance, bottom_distance))
	}

	return CSSPixelSize.new(style_values_extra_css_min(left_distance, right_distance), style_values_extra_css_min(top_distance, bottom_distance))
}

fn style_values_extra_closest_side_shape(center CSSPixelPoint, reference_box CSSPixelRect) CSSPixelSize {
	return style_values_extra_side_shape(center, reference_box, false)
}

fn style_values_extra_farthest_side_shape(center CSSPixelPoint, reference_box CSSPixelRect) CSSPixelSize {
	return style_values_extra_side_shape(center, reference_box, true)
}

fn style_values_extra_corner_distance(center CSSPixelPoint, reference_box CSSPixelRect, use_farthest bool) (CSSPixels, CSSPixelPoint) {
	corners := [
		CSSPixelPoint.new(style_values_extra_rect_left(reference_box), style_values_extra_rect_top(reference_box)),
		CSSPixelPoint.new(style_values_extra_rect_right(reference_box), style_values_extra_rect_top(reference_box)),
		CSSPixelPoint.new(style_values_extra_rect_right(reference_box), style_values_extra_rect_bottom(reference_box)),
		CSSPixelPoint.new(style_values_extra_rect_left(reference_box), style_values_extra_rect_bottom(reference_box)),
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

fn style_values_extra_path_from_resolved_rect(top CSSPixels, right CSSPixels, bottom CSSPixels, left CSSPixels) StyleValuePath {
	return StyleValuePath{
		commands: [
			style_values_extra_move_to(CSSPixelPoint.new(left, top)),
			style_values_extra_line_to(CSSPixelPoint.new(right, top)),
			style_values_extra_line_to(CSSPixelPoint.new(right, bottom)),
			style_values_extra_line_to(CSSPixelPoint.new(left, bottom)),
			style_values_extra_close_path(),
		]
	}
}

fn style_values_extra_translated_to_origin(reference_box CSSPixelRect) CSSPixelRect {
	return CSSPixelRect{
		x: CSSPixels.new(0)
		y: CSSPixels.new(0)
		width: reference_box.width
		height: reference_box.height
	}
}

fn style_values_extra_radial_size_from_style_value(style_value StyleValue) ?RadialSizeStyleValue {
	return match style_value {
		RadialSizeStyleValue { style_value }
		else { none }
	}
}

fn style_values_extra_position_from_style_value(style_value ?StyleValue) PositionStyleValue {
	if value := style_value {
		return value.as_position()
	}
	return PositionStyleValue.create_computed_center()
}

struct StyleValuesExtraResolvedBorderRadius {
mut:
	horizontal CSSPixels
	vertical   CSSPixels
}

struct StyleValuesExtraResolvedBorderRadii {
mut:
	top_left     StyleValuesExtraResolvedBorderRadius
	top_right    StyleValuesExtraResolvedBorderRadius
	bottom_right StyleValuesExtraResolvedBorderRadius
	bottom_left  StyleValuesExtraResolvedBorderRadius
}

fn style_values_extra_resolve_border_radius(value StyleValue, context LengthResolutionContext, reference_box CSSPixelRect) StyleValuesExtraResolvedBorderRadius {
	radius := value.as_border_radius() or { panic('VERIFY_NOT_REACHED') }
	return StyleValuesExtraResolvedBorderRadius{
		horizontal: style_values_extra_length_percentage_to_px(radius.horizontal_radius[0], context, reference_box.width)
		vertical: style_values_extra_length_percentage_to_px(radius.vertical_radius[0], context, reference_box.height)
	}
}

// Direct translation of Painting::normalize_border_radii_data(). The CSS module
// cannot import Painting (Painting depends on CSS), so the fixed-point
// normalization remains beside the BasicShape path translation.
fn style_values_extra_normalize_border_radii(border_radius StyleValue, context LengthResolutionContext, inset_rect CSSPixelRect, reference_box CSSPixelRect) StyleValuesExtraResolvedBorderRadii {
	border_radius_rect := match border_radius {
		BorderRadiusRectStyleValue { border_radius }
		else { panic('VERIFY_NOT_REACHED') }
	}
	mut radii := StyleValuesExtraResolvedBorderRadii{
		top_left: style_values_extra_resolve_border_radius(border_radius_rect.top_left(), context, reference_box)
		top_right: style_values_extra_resolve_border_radius(border_radius_rect.top_right(), context, reference_box)
		bottom_right: style_values_extra_resolve_border_radius(border_radius_rect.bottom_right(), context, reference_box)
		bottom_left: style_values_extra_resolve_border_radius(border_radius_rect.bottom_left(), context, reference_box)
	}

	// Two passes are intentional. Upstream uses iterative refinement because a
	// single fixed-point scaling pass can leave a one-unit overflow.
	for _ in 0 .. 2 {
		s_top := radii.top_left.horizontal.plus(radii.top_right.horizontal)
		s_right := radii.top_right.vertical.plus(radii.bottom_right.vertical)
		s_bottom := radii.bottom_right.horizontal.plus(radii.bottom_left.horizontal)
		s_left := radii.bottom_left.vertical.plus(radii.top_left.vertical)

		mut factor := 1.0
		if s_top.compare(inset_rect.width) > 0 {
			factor = math.min(factor, inset_rect.width.to_double() / s_top.to_double())
		}
		if s_right.compare(inset_rect.height) > 0 {
			factor = math.min(factor, inset_rect.height.to_double() / s_right.to_double())
		}
		if s_bottom.compare(inset_rect.width) > 0 {
			factor = math.min(factor, inset_rect.width.to_double() / s_bottom.to_double())
		}
		if s_left.compare(inset_rect.height) > 0 {
			factor = math.min(factor, inset_rect.height.to_double() / s_left.to_double())
		}
		if factor >= 1.0 {
			break
		}

		radii.top_left.horizontal = radii.top_left.horizontal.scaled(factor)
		radii.top_left.vertical = radii.top_left.vertical.scaled(factor)
		radii.top_right.horizontal = radii.top_right.horizontal.scaled(factor)
		radii.top_right.vertical = radii.top_right.vertical.scaled(factor)
		radii.bottom_right.horizontal = radii.bottom_right.horizontal.scaled(factor)
		radii.bottom_right.vertical = radii.bottom_right.vertical.scaled(factor)
		radii.bottom_left.horizontal = radii.bottom_left.horizontal.scaled(factor)
		radii.bottom_left.vertical = radii.bottom_left.vertical.scaled(factor)
	}
	return radii
}

fn style_values_extra_inset_to_path(shape BasicShapeInset, reference_box CSSPixelRect, node &dom.LayoutNode) StyleValuePath {
	context := style_values_extra_length_context(node)
	resolved_top := style_values_extra_length_percentage_to_px(shape.top, context, reference_box.height)
	resolved_right := style_values_extra_length_percentage_to_px(shape.right, context, reference_box.width)
	resolved_bottom := style_values_extra_length_percentage_to_px(shape.bottom, context, reference_box.height)
	resolved_left := style_values_extra_length_percentage_to_px(shape.left, context, reference_box.width)

	mut top := resolved_top.to_double()
	mut right := resolved_right.to_double()
	mut bottom := resolved_bottom.to_double()
	mut left := resolved_left.to_double()

	// A pair of insets in either dimension that add up to more than the used dimension
	// (such as left and right insets of 75% apiece) use the CSS Backgrounds 3 4.5 Overlapping Curves rules
	// to proportionally reduce the inset effect to 100%.
	if top + bottom > reference_box.height.to_double()
		|| left + right > reference_box.width.to_double() {
		// https://drafts.csswg.org/css-backgrounds-3/#corner-overlap
		// Let f = min(Li/Si), where i in {top, right, bottom, left}, Si is the sum of the two corresponding radii of the
		// corners on side i, and Ltop = Lbottom = the width of the box, and Lleft = Lright = the height of the box. If
		// f < 1, then all corner radii are reduced by multiplying them by f.

		// NB: We only care about vertical and horizontal here as top = bottom and left = right
		s_vertical := top + bottom
		s_horizontal := left + right
		f := math.min(reference_box.height.to_double() / s_vertical, reference_box.width.to_double() / s_horizontal)

		top *= f
		right *= f
		bottom *= f
		left *= f
	}

	left_edge := CSSPixels.nearest_value_for(left)
	top_edge := CSSPixels.nearest_value_for(top)
	right_edge := CSSPixels.nearest_value_for(reference_box.width.to_double() - right)
	bottom_edge := CSSPixels.nearest_value_for(reference_box.height.to_double() - bottom)

	inset_rect := CSSPixelRect{
		x: left_edge
		y: top_edge
		width: right_edge.minus(left_edge)
		height: bottom_edge.minus(top_edge)
	}
	radii := style_values_extra_normalize_border_radii(shape.border_radius, context, inset_rect, reference_box)
	if radii.top_left.horizontal.raw_value() == 0
		&& radii.top_left.vertical.raw_value() == 0
		&& radii.top_right.horizontal.raw_value() == 0
		&& radii.top_right.vertical.raw_value() == 0
		&& radii.bottom_right.horizontal.raw_value() == 0
		&& radii.bottom_right.vertical.raw_value() == 0
		&& radii.bottom_left.horizontal.raw_value() == 0
		&& radii.bottom_left.vertical.raw_value() == 0 {
		return style_values_extra_path_from_resolved_rect(top_edge, right_edge, bottom_edge, left_edge)
	}

	mut path := StyleValuePath{}
	path.commands << style_values_extra_move_to(CSSPixelPoint.new(left_edge.plus(radii.top_left.horizontal), top_edge))
	path.commands << style_values_extra_line_to(CSSPixelPoint.new(right_edge.minus(radii.top_right.horizontal), top_edge))
	if radii.top_right.horizontal.raw_value() > 0 && radii.top_right.vertical.raw_value() > 0 {
		path.commands << style_values_extra_elliptical_arc_to(CSSPixelPoint.new(right_edge, top_edge.plus(radii.top_right.vertical)), CSSPixelSize.new(radii.top_right.horizontal, radii.top_right.vertical), false, true)
	}
	path.commands << style_values_extra_line_to(CSSPixelPoint.new(right_edge, bottom_edge.minus(radii.bottom_right.vertical)))
	if radii.bottom_right.horizontal.raw_value() > 0 && radii.bottom_right.vertical.raw_value() > 0 {
		path.commands << style_values_extra_elliptical_arc_to(CSSPixelPoint.new(right_edge.minus(radii.bottom_right.horizontal), bottom_edge), CSSPixelSize.new(radii.bottom_right.horizontal, radii.bottom_right.vertical), false, true)
	}
	path.commands << style_values_extra_line_to(CSSPixelPoint.new(left_edge.plus(radii.bottom_left.horizontal), bottom_edge))
	if radii.bottom_left.horizontal.raw_value() > 0 && radii.bottom_left.vertical.raw_value() > 0 {
		path.commands << style_values_extra_elliptical_arc_to(CSSPixelPoint.new(left_edge, bottom_edge.minus(radii.bottom_left.vertical)), CSSPixelSize.new(radii.bottom_left.horizontal, radii.bottom_left.vertical), false, true)
	}
	path.commands << style_values_extra_line_to(CSSPixelPoint.new(left_edge, top_edge.plus(radii.top_left.vertical)))
	if radii.top_left.horizontal.raw_value() > 0 && radii.top_left.vertical.raw_value() > 0 {
		path.commands << style_values_extra_elliptical_arc_to(CSSPixelPoint.new(left_edge.plus(radii.top_left.horizontal), top_edge), CSSPixelSize.new(radii.top_left.horizontal, radii.top_left.vertical), false, true)
	}
	path.commands << style_values_extra_close_path()
	return path
}

fn style_values_extra_circle_to_path(shape BasicShapeCircle, reference_box CSSPixelRect, node &dom.LayoutNode) StyleValuePath {
	translated_reference_box := style_values_extra_translated_to_origin(reference_box)

	// https://www.w3.org/TR/css-shapes/#funcdef-basic-shape-circle
	// The <position> argument defines the center of the circle. Unless otherwise specified, this defaults to center if omitted.
	resolved_position := style_values_extra_position_from_style_value(shape.position)
	center := resolved_position.resolved(node, translated_reference_box)
	radius := style_values_extra_radial_size_from_style_value(shape.radius) or {
		return StyleValuePath{
			commands: [style_values_extra_svg_path(shape.serialize(.normal))]
		}
	}
	radius_px := radius.resolve_circle_size(center, translated_reference_box, node)

	return StyleValuePath{
		commands: [
			style_values_extra_move_to(CSSPixelPoint.new(center.x(), center.y().plus(radius_px))),
			style_values_extra_elliptical_arc_to(CSSPixelPoint.new(center.x(), center.y().minus(radius_px)), CSSPixelSize.new(radius_px, radius_px), true, true),
			style_values_extra_elliptical_arc_to(CSSPixelPoint.new(center.x(), center.y().plus(radius_px)), CSSPixelSize.new(radius_px, radius_px), true, true),
		]
	}
}

fn style_values_extra_ellipse_to_path(shape BasicShapeEllipse, reference_box CSSPixelRect, node &dom.LayoutNode) StyleValuePath {
	translated_reference_box := style_values_extra_translated_to_origin(reference_box)

	// https://www.w3.org/TR/css-shapes/#funcdef-basic-shape-circle
	// The <position> argument defines the center of the ellipse. Unless otherwise specified, this defaults to center if omitted.
	resolved_position := style_values_extra_position_from_style_value(shape.position)
	center := resolved_position.resolved(node, translated_reference_box)
	radius := style_values_extra_radial_size_from_style_value(shape.radius) or {
		return StyleValuePath{
			commands: [style_values_extra_svg_path(shape.serialize(.normal))]
		}
	}
	size := radius.resolve_ellipse_size(center, translated_reference_box, node)

	return StyleValuePath{
		commands: [
			style_values_extra_move_to(CSSPixelPoint.new(center.x(), center.y().plus(size.height()))),
			style_values_extra_elliptical_arc_to(CSSPixelPoint.new(center.x(), center.y().minus(size.height())), size, true, true),
			style_values_extra_elliptical_arc_to(CSSPixelPoint.new(center.x(), center.y().plus(size.height())), size, true, true),
		]
	}
}

fn style_values_extra_polygon_to_path(shape BasicShapePolygon, reference_box CSSPixelRect, node &dom.LayoutNode) StyleValuePath {
	context := style_values_extra_length_context(node)
	mut commands := []StyleValuePathCommand{}
	radius := style_values_extra_length_percentage_to_px(shape.round_radius,context,reference_box.width).to_double()
	if radius > 0 && shape.points.len >= 3 { return rounded_polygon_to_path(shape,reference_box,node,radius) }
	for index, point in shape.points {
		x := style_values_extra_length_percentage_to_px(point.x, context, reference_box.width)
		y := style_values_extra_length_percentage_to_px(point.y, context, reference_box.height)
		commands << if index == 0 {
			style_values_extra_move_to(CSSPixelPoint.new(x, y))
		} else {
			style_values_extra_line_to(CSSPixelPoint.new(x, y))
		}
	}
	commands << style_values_extra_close_path()
	return StyleValuePath{
		commands: commands
		fill_rule: shape.fill_rule
	}
}

fn style_values_extra_xywh_to_inset(shape BasicShapeXywh) BasicShapeInset {
	// Given xywh(x y w h), the equivalent inset() is:
	// inset(y calc(100% - x - w) calc(100% - y - h) x).
	return BasicShapeInset{
		top: shape.y
		right: style_values_extra_one_hundred_percent_minus_serialized([shape.x, shape.width])
		bottom: style_values_extra_one_hundred_percent_minus_serialized([shape.y, shape.height])
		left: shape.x
		border_radius: shape.border_radius
	}
}

fn style_values_extra_rect_to_inset(shape BasicShapeRect) BasicShapeInset {
	// Given rect(t r b l), the equivalent inset() is:
	// inset(t calc(100% - r) calc(100% - b) l).
	return BasicShapeInset{
		top: style_values_extra_rect_resolve_auto(shape.top, 0)
		right: style_values_extra_one_hundred_percent_minus_serialized([
			style_values_extra_rect_resolve_auto(shape.right, 100),
		])
		bottom: style_values_extra_one_hundred_percent_minus_serialized([
			style_values_extra_rect_resolve_auto(shape.bottom, 100),
		])
		left: style_values_extra_rect_resolve_auto(shape.left, 0)
		border_radius: shape.border_radius
	}
}

fn style_values_extra_rect_resolve_auto(style_value StyleValue, value_of_auto f64) StyleValue {
	if style_value.is_keyword() {
		if style_value.to_keyword() != .auto {
			panic('VERIFY_NOT_REACHED')
		}
		return StyleValue(PercentageStyleValue.create(Percentage.new(value_of_auto)))
	}
	return style_value
}

fn style_values_extra_one_hundred_percent_minus_serialized(values []StyleValue) StyleValue {
	if values.len == 0 {
		return StyleValue(PercentageStyleValue.create(Percentage.new(100)))
	}

	mut all_values_are_percentages := true
	mut percentage_total := 0.0
	for value in values {
		if percentage_value := style_values_extra_percentage_value(value) {
			percentage_total += percentage_value
		} else {
			all_values_are_percentages = false
		}
	}

	if all_values_are_percentages {
		return StyleValue(PercentageStyleValue.create(Percentage.new(100.0 - percentage_total)))
	}

	mut serialized := 'calc(100%'
	for value in values {
		serialized += ' - ${value.serialize(.normal)}'
	}
	serialized += ')'
	return calculated_style_value_from_text(serialized)
}

fn style_values_extra_percentage_value(style_value StyleValue) ?f64 {
	return match style_value {
		PercentageStyleValue { style_value.percentage().value() }
		else { none }
	}
}

// --- CursorStyleValue extra helpers ---

pub fn (style_value CursorStyleValue) image() CursorImageValue {
	return style_value.image_[0]
}

pub fn (style_value CursorStyleValue) x() ?StyleValue {
	return style_value_from_optional_storage(style_value.x_)
}

pub fn (style_value CursorStyleValue) y() ?StyleValue {
	return style_value_from_optional_storage(style_value.y_)
}

fn style_values_extra_image_natural_size(image CSSImageSourceStyleValue) SizeWithAspectRatio {
	return match image {
		ImageStyleValue {
			SizeWithAspectRatio{
				width: image.natural_width()
				height: image.natural_height()
				aspect_ratio: image.natural_aspect_ratio()
			}
		}
		ImageSetStyleValue {
			SizeWithAspectRatio{
				width: image.natural_width()
				height: image.natural_height()
				aspect_ratio: image.natural_aspect_ratio()
			}
		}
		else { SizeWithAspectRatio{} }
	}
}

fn style_values_extra_image_is_paintable(image CSSImageSourceStyleValue) bool {
	return match image {
		ImageStyleValue { image.is_paintable() }
		ImageSetStyleValue { image.is_paintable() }
		ConicGradientStyleValue, LinearGradientStyleValue, RadialGradientStyleValue { true }
		StyleValue { false }
	}
}

pub fn (mut style_value CursorStyleValue) make_image_cursor(node &dom.LayoutNode) ?StyleValueImageCursor {
	mut image := style_value.image_[0].value
	if !style_values_extra_image_is_paintable(image) {
		match mut image {
			ImageStyleValue {
				mut document := document_from_layout_node(node) or { return none }
				image.load_any_resources(mut document)
				style_value.image_ = [CursorImageValue.create(CSSImageSourceStyleValue(image))]
			}
			ImageSetStyleValue {
				mut document := document_from_layout_node(node) or { return none }
				image.load_any_resources(mut document, document.device_pixels_per_css_pixel())
				style_value.image_ = [CursorImageValue.create(CSSImageSourceStyleValue(image))]
			}
			else {}
		}
		return none
	}

	// CSS UI 3: use the default sizing algorithm with a UA-defined typical
	// cursor size. Upstream currently chooses 32x32 CSS pixels.
	default_cursor_size := CSSPixelSize.new(CSSPixels.new(32), CSSPixels.new(32))
	cursor_size := run_default_sizing_algorithm(none, none, style_values_extra_image_natural_size(image), default_cursor_size)

	mut hotspot_x := 0
	mut hotspot_y := 0
	if x := style_value.x() {
		y := style_value.y() or { panic('VERIFY_NOT_REACHED') }
		hotspot_x = int(number_from_style_value(x, none))
		hotspot_y = int(number_from_style_value(y, none))
	}

	return StyleValueImageCursor{
		image: image
		size: cursor_size
		hotspot_x: hotspot_x
		hotspot_y: hotspot_y
	}
}

// --- BasicShapeStyleValue extra helpers ---

pub fn (style_value BasicShapeStyleValue) to_path(reference_box CSSPixelRect, node &dom.LayoutNode) StyleValuePath {
	shape := style_value.basic_shape_[0]
	return match shape {
		BasicShapeCommands { shape.to_path(reference_box,node) }
		BasicShapeInset {
			style_values_extra_inset_to_path(shape, reference_box, node)
		}
		BasicShapeCircle {
			style_values_extra_circle_to_path(shape, reference_box, node)
		}
		BasicShapeEllipse {
			style_values_extra_ellipse_to_path(shape, reference_box, node)
		}
		BasicShapePolygon {
			style_values_extra_polygon_to_path(shape, reference_box, node)
		}
		BasicShapeXywh {
			style_values_extra_inset_to_path(style_values_extra_xywh_to_inset(shape), reference_box, node)
		}
		BasicShapeRect {
			style_values_extra_inset_to_path(style_values_extra_rect_to_inset(shape), reference_box, node)
		}
		BasicShapePath {
			StyleValuePath{
				commands: [
					style_values_extra_svg_path(shape.path_instructions),
				]
				fill_rule: shape.fill_rule
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

pub fn (style_value PositionStyleValue) resolved(node &dom.LayoutNode, rect CSSPixelRect) CSSPixelPoint {
	// Note: A preset + a none default x/y_relative_to is impossible in the syntax and makes little sense.
	context := style_values_extra_length_context(node)
	x := style_values_extra_length_percentage_to_px(style_value.edge_x_.offset(), context, rect.width)
	y := style_values_extra_length_percentage_to_px(style_value.edge_y_.offset(), context, rect.height)
	return CSSPixelPoint.new(rect.x.plus(x), rect.y.plus(y))
}

pub fn (style_value RadialSizeStyleValue) resolve_circle_size(center CSSPixelPoint, reference_box CSSPixelRect, node &dom.LayoutNode) CSSPixels {
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
			context := style_values_extra_length_context(node)
			radius_ref := math.sqrt(reference_box.width.to_double() * reference_box.width.to_double() + reference_box.height.to_double() * reference_box.height.to_double()) / math.sqrt(2.0)
			resolved := style_values_extra_length_percentage_to_px(component, context, CSSPixels.nearest_value_for(radius_ref))
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

pub fn (style_value RadialSizeStyleValue) resolve_ellipse_size(center CSSPixelPoint, reference_box CSSPixelRect, node &dom.LayoutNode) CSSPixelSize {
	if style_value.components_.len != 1 && style_value.components_.len != 2 {
		panic('VERIFY_NOT_REACHED')
	}

	first_size := style_value.resolve_ellipse_component(style_value.components_[0], center, reference_box, node, reference_box.width)
	second_component := if style_value.components_.len == 1 {
		style_value.components_[0]
	} else {
		style_value.components_[1]
	}
	second_size := style_value.resolve_ellipse_component(second_component, center, reference_box, node, reference_box.height)
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

fn (style_value RadialSizeStyleValue) resolve_ellipse_component(component RadialSizeStyleValueComponent, center CSSPixelPoint, reference_box CSSPixelRect, node &dom.LayoutNode, reference_size CSSPixels) CSSPixelSize {
	_ = style_value
	return match component {
		RadialExtentComponent {
			match component.extent {
				.closest_side {
					style_values_extra_closest_side_shape(center, reference_box)
				}
				.farthest_side {
					style_values_extra_farthest_side_shape(center, reference_box)
				}
				.closest_corner {
					style_values_extra_ellipse_corner_shape(center, reference_box, false)
				}
				.farthest_corner {
					style_values_extra_ellipse_corner_shape(center, reference_box, true)
				}
			}
		}
		StyleValue {
			context := style_values_extra_length_context(node)
			value := style_values_extra_length_percentage_to_px(component, context, reference_size)
			CSSPixelSize.new(value, value)
		}
	}
}

// --- RandomValueSharingStyleValue extra helpers ---

pub fn (style_value RandomValueSharingStyleValue) is_fixed() bool {
	return style_value.fixed_value_ != unsafe { nil }
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
	if style_value.fixed_value_ != unsafe { nil } {
		return none
	}
	name := style_value.name_ or { return none }
	return RandomCachingKey{
		name: name
		element_id: if style_value.element_shared_ || !style_value.is_auto_ { none } else { element_id }
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

pub fn (mut style_value ShorthandStyleValue) set_style_sheet(style_sheet ?&CSSStyleSheet) {
	for index, child in style_value.values_ {
		mut mutable_child := child
		mutable_child.set_style_sheet(style_sheet)
		style_value.values_[index] = mutable_child
	}
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

pub fn (mut style_value StyleValueList) set_style_sheet(style_sheet ?&CSSStyleSheet) {
	for index, child in style_value.values_ {
		mut mutable_child := child
		mutable_child.set_style_sheet(style_sheet)
		style_value.values_[index] = mutable_child
	}
}

// --- TreeCountingFunctionStyleValue extra helpers ---

pub fn (style_value TreeCountingFunctionStyleValue) function() TreeCountingFunction {
	return style_value.function_
}

pub fn (style_value TreeCountingFunctionStyleValue) computed_type() TreeCountingComputedType {
	return style_value.computed_type_
}

// --- UnresolvedStyleValue extra helpers ---

pub fn (style_value UnresolvedStyleValue) values() []ComponentValue {
	return style_value.tokens
}

pub fn (style_value UnresolvedStyleValue) tokenize() []ComponentValue {
	return style_value.tokens
}

pub fn (style_value UnresolvedStyleValue) substitution_functions_presence() SubstitutionFunctionsPresence {
	return style_value.substitution_functions_presence
}

pub fn (style_value UnresolvedStyleValue) contains_arbitrary_substitution_function() bool {
	return style_value.substitution_functions_presence().has_any()
}

pub fn (style_value UnresolvedStyleValue) includes_attr_function() bool {
	return style_value.substitution_functions_presence().attr
}

pub fn (style_value UnresolvedStyleValue) includes_custom_function() bool {
	return style_value.substitution_functions_presence().custom_function
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

fn rounded_polygon_to_path(shape BasicShapePolygon,box CSSPixelRect,node &dom.LayoutNode,radius f64) StyleValuePath {
 context := style_values_extra_length_context(node)
 mut points := []CSSPixelPoint{}
 for point in shape.points {
  points << CSSPixelPoint.new(box.x.plus(style_values_extra_length_percentage_to_px(point.x,context,box.width)),box.y.plus(style_values_extra_length_percentage_to_px(point.y,context,box.height)))
 }
 mut entries := []CSSPixelPoint{}
 mut exits := []CSSPixelPoint{}
 mut radii := []f64{}
 mut sweeps := []bool{}
 for i,point in points {
  previous,next := points[(i+points.len-1)%points.len],points[(i+1)%points.len]
  px,py := previous.x().minus(point.x()).to_double(),previous.y().minus(point.y()).to_double()
  nx,ny := next.x().minus(point.x()).to_double(),next.y().minus(point.y()).to_double()
  a,b := math.hypot(px,py),math.hypot(nx,ny)
  if a == 0 || b == 0 { entries << point;exits << point;radii << 0;sweeps << false;continue }
  ux,uy,vx,vy := px/a,py/a,nx/b,ny/b
  tangent := math.tan(math.acos(math.max(-1.0,math.min(1.0,ux*vx+uy*vy)))/2)
  distance := if tangent == 0 { 0.0 } else { math.min(radius/tangent,math.min(a,b)/2) }
  entries << CSSPixelPoint.new(point.x().plus(CSSPixels.nearest_value_for(ux*distance)),point.y().plus(CSSPixels.nearest_value_for(uy*distance)))
  exits << CSSPixelPoint.new(point.x().plus(CSSPixels.nearest_value_for(vx*distance)),point.y().plus(CSSPixels.nearest_value_for(vy*distance)))
  radii << distance*tangent
  sweeps << uy*vx-ux*vy >= 0
 }
 mut commands := [style_values_extra_move_to(entries[0])]
 for i in 0..points.len {
  if i > 0 { commands << style_values_extra_line_to(entries[i]) }
  if radii[i] > 0 {
   r := CSSPixels.nearest_value_for(radii[i])
   commands << style_values_extra_elliptical_arc_to(exits[i],CSSPixelSize{width_:r,height_:r},false,sweeps[i])
  } else { commands << style_values_extra_line_to(exits[i]) }
 }
 commands << style_values_extra_close_path()
 return StyleValuePath{commands:commands,fill_rule:shape.fill_rule}
}
