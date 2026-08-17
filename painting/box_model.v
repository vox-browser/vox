module painting

import math

pub struct Color {
pub:
	r u8
	g u8
	b u8
	a u8 = 255
}

pub const transparent = Color{
	a: 0
}

pub struct PixelBox {
pub:
	top    f64
	right  f64
	bottom f64
	left   f64
}

pub struct BoxModelMetrics {
pub:
	margin  PixelBox
	padding PixelBox
	border  PixelBox
	inset   PixelBox
}

pub fn (metrics BoxModelMetrics) margin_box() PixelBox {
	return PixelBox{
		top:    metrics.margin.top + metrics.border.top + metrics.padding.top
		right:  metrics.margin.right + metrics.border.right + metrics.padding.right
		bottom: metrics.margin.bottom + metrics.border.bottom + metrics.padding.bottom
		left:   metrics.margin.left + metrics.border.left + metrics.padding.left
	}
}

pub fn (metrics BoxModelMetrics) padding_box() PixelBox {
	return metrics.padding
}

pub fn (metrics BoxModelMetrics) border_box() PixelBox {
	return PixelBox{
		top:    metrics.border.top + metrics.padding.top
		right:  metrics.border.right + metrics.padding.right
		bottom: metrics.border.bottom + metrics.padding.bottom
		left:   metrics.border.left + metrics.padding.left
	}
}

pub struct CornerRadius {
pub mut:
	horizontal int
	vertical   int
}

pub fn (radius CornerRadius) is_present() bool {
	return radius.horizontal > 0 && radius.vertical > 0
}

pub struct BorderRadiusData {
pub mut:
	horizontal f64
	vertical   f64
}

pub fn (radius BorderRadiusData) is_present() bool {
	return radius.horizontal > 0 && radius.vertical > 0
}

pub fn (radius BorderRadiusData) as_corner(converter DevicePixelConverter) CornerRadius {
	return CornerRadius{
		horizontal: converter.floored_device_pixels(radius.horizontal)
		vertical:   converter.floored_device_pixels(radius.vertical)
	}
}

pub fn (mut radius BorderRadiusData) shrink(horizontal f64, vertical f64) {
	if radius.horizontal != 0 {
		radius.horizontal = math.max(0.0, radius.horizontal - horizontal)
	}
	if radius.vertical != 0 {
		radius.vertical = math.max(0.0, radius.vertical - vertical)
	}
}

pub struct CornerRadii {
pub mut:
	top_left     CornerRadius
	top_right    CornerRadius
	bottom_right CornerRadius
	bottom_left  CornerRadius
}

pub fn (radii CornerRadii) has_any_radius() bool {
	return radii.top_left.is_present() || radii.top_right.is_present()
		|| radii.bottom_right.is_present() || radii.bottom_left.is_present()
}

fn outside_ellipse(point IntPoint, radius CornerRadius, center IntPoint) bool {
	dx := f64(point.x - center.x) / f64(radius.horizontal)
	dy := f64(point.y - center.y) / f64(radius.vertical)
	return dx * dx + dy * dy > 1.0
}

pub fn (radii CornerRadii) contains(point IntPoint, rect IntRect) bool {
	if !rect.contains(point) {
		return false
	}
	if !radii.has_any_radius() {
		return true
	}
	if radii.top_left.is_present() {
		center := IntPoint{rect.left() + radii.top_left.horizontal, rect.top() +
			radii.top_left.vertical}
		if point.x < center.x && point.y < center.y
			&& outside_ellipse(point, radii.top_left, center) {
			return false
		}
	}
	if radii.top_right.is_present() {
		center := IntPoint{rect.right() - radii.top_right.horizontal, rect.top() +
			radii.top_right.vertical}
		if point.x > center.x && point.y < center.y
			&& outside_ellipse(point, radii.top_right, center) {
			return false
		}
	}
	if radii.bottom_right.is_present() {
		center :=
			IntPoint{rect.right() - radii.bottom_right.horizontal, rect.bottom() - radii.bottom_right.vertical}
		if point.x > center.x && point.y > center.y
			&& outside_ellipse(point, radii.bottom_right, center) {
			return false
		}
	}
	if radii.bottom_left.is_present() {
		center :=
			IntPoint{rect.left() + radii.bottom_left.horizontal, rect.bottom() - radii.bottom_left.vertical}
		if point.x < center.x && point.y > center.y
			&& outside_ellipse(point, radii.bottom_left, center) {
			return false
		}
	}
	return true
}

fn spread_radius(value int, distance int) int {
	if value == 0 || distance == 0 {
		return value
	}
	if value > abs_int(distance) {
		return value + distance
	}
	ratio := f64(value) / f64(abs_int(distance))
	// Assignment to the integer radius truncates exactly as in the C++ source.
	return value + int(f64(distance) * (1.0 + math.pow(ratio - 1.0, 3.0)))
}

pub fn (mut radii CornerRadii) adjust_for_spread_distance(distance int) {
	radii.top_left.horizontal = spread_radius(radii.top_left.horizontal, distance)
	radii.top_left.vertical = spread_radius(radii.top_left.vertical, distance)
	radii.top_right.horizontal = spread_radius(radii.top_right.horizontal, distance)
	radii.top_right.vertical = spread_radius(radii.top_right.vertical, distance)
	radii.bottom_right.horizontal = spread_radius(radii.bottom_right.horizontal, distance)
	radii.bottom_right.vertical = spread_radius(radii.bottom_right.vertical, distance)
	radii.bottom_left.horizontal = spread_radius(radii.bottom_left.horizontal, distance)
	radii.bottom_left.vertical = spread_radius(radii.bottom_left.vertical, distance)
}

pub struct BorderRadiiData {
pub mut:
	top_left     BorderRadiusData
	top_right    BorderRadiusData
	bottom_right BorderRadiusData
	bottom_left  BorderRadiusData
}

pub fn (radii BorderRadiiData) has_any_radius() bool {
	return radii.top_left.is_present() || radii.top_right.is_present()
		|| radii.bottom_right.is_present() || radii.bottom_left.is_present()
}

pub fn (radii BorderRadiiData) contains(point Point, rect Rect) bool {
	if !rect.contains(point) {
		return false
	}
	corners := CornerRadii{
		top_left:     CornerRadius{int(radii.top_left.horizontal), int(radii.top_left.vertical)}
		top_right:    CornerRadius{int(radii.top_right.horizontal), int(radii.top_right.vertical)}
		bottom_right: CornerRadius{int(radii.bottom_right.horizontal), int(radii.bottom_right.vertical)}
		bottom_left:  CornerRadius{int(radii.bottom_left.horizontal), int(radii.bottom_left.vertical)}
	}
	return corners.contains(IntPoint{int(point.x), int(point.y)}, IntRect{int(rect.x), int(rect.y), int(rect.width), int(rect.height)})
}

pub fn (mut radii BorderRadiiData) shrink(top f64, right f64, bottom f64, left f64) {
	radii.top_left.shrink(left, top)
	radii.top_right.shrink(right, top)
	radii.bottom_right.shrink(right, bottom)
	radii.bottom_left.shrink(left, bottom)
}

pub fn (mut radii BorderRadiiData) inflate(top f64, right f64, bottom f64, left f64) {
	radii.shrink(-top, -right, -bottom, -left)
}

pub fn (radii BorderRadiiData) as_corners(converter DevicePixelConverter) CornerRadii {
	if !radii.has_any_radius() {
		return CornerRadii{}
	}
	return CornerRadii{
		top_left:     radii.top_left.as_corner(converter)
		top_right:    radii.top_right.as_corner(converter)
		bottom_right: radii.bottom_right.as_corner(converter)
		bottom_left:  radii.bottom_left.as_corner(converter)
	}
}

pub enum BorderEdge {
	top
	right
	bottom
	left
}

pub enum LineStyle {
	none
	hidden
	dotted
	dashed
	solid
	double
	groove
	ridge
	inset
	outset
}

pub struct BorderData {
pub:
	color      Color
	line_style LineStyle
	width      f64
}

pub struct DeviceBorderData {
pub:
	color      Color
	line_style LineStyle
	width      int
}

pub struct BordersData {
pub:
	top    BorderData
	right  BorderData
	bottom BorderData
	left   BorderData
}

pub struct DeviceBordersData {
pub:
	top    DeviceBorderData
	right  DeviceBorderData
	bottom DeviceBorderData
	left   DeviceBorderData
}

pub fn (borders BordersData) to_device_pixels(converter DevicePixelConverter) DeviceBordersData {
	return DeviceBordersData{
		top:    DeviceBorderData{borders.top.color, borders.top.line_style, converter.enclosing_device_pixels(borders.top.width)}
		right:  DeviceBorderData{borders.right.color, borders.right.line_style, converter.enclosing_device_pixels(borders.right.width)}
		bottom: DeviceBorderData{borders.bottom.color, borders.bottom.line_style, converter.enclosing_device_pixels(borders.bottom.width)}
		left:   DeviceBorderData{borders.left.color, borders.left.line_style, converter.enclosing_device_pixels(borders.left.width)}
	}
}

pub fn (borders DeviceBordersData) for_edge(edge BorderEdge) DeviceBorderData {
	return match edge {
		.top { borders.top }
		.right { borders.right }
		.bottom { borders.bottom }
		.left { borders.left }
	}
}

pub struct ChromeMetrics {
pub:
	scroll_thumb_min_length     f64
	scroll_thumb_padding_thin   f64
	scroll_thumb_thickness_thin f64
	scroll_thumb_thickness      f64
	scroll_gutter_thickness     f64
	resize_gripper_size         f64
	resize_gripper_padding      f64
}

pub fn new_chrome_metrics(zoom_factor f64) !ChromeMetrics {
	if zoom_factor <= 0 || math.is_nan(zoom_factor) || math.is_inf(zoom_factor, 0) {
		return error('zoom factor must be finite and positive')
	}
	inverse := 1.0 / zoom_factor
	return ChromeMetrics{
		scroll_thumb_min_length:     24.0 * inverse
		scroll_thumb_padding_thin:   2.0 * inverse
		scroll_thumb_thickness_thin: 6.0 * inverse
		scroll_thumb_thickness:      8.0 * inverse
		scroll_gutter_thickness:     12.0 * inverse
		resize_gripper_size:         12.0 * inverse
		resize_gripper_padding:      2.0 * inverse
	}
}
