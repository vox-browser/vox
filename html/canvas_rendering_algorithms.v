// Copyright (c) 2020-2026, Ladybird contributors
// Copyright (c) 2026-present, the Ladybird developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Concrete translations of CanvasRenderingContext2D.cpp and the corresponding
// OffscreenCanvasRenderingContext2D entry points. The backing painter in this
// port is the RGBA bitmap owned by OffscreenCanvas.
module html

import css
import dom
import math
import platform
import strconv
import svg

pub struct CanvasFloatRect {
pub:
	x      f64
	y      f64
	width  f64
	height f64
}

pub struct PreparedCanvasText {
pub:
	text         string
	physical_x   f64
	physical_y   f64
	bounding_box CanvasFloatRect
	font_size    f64
}

fn resolved_letter_spacing(drawing_state DrawingState) f64 {
	return drawing_state.letter_spacing_px
}

fn canvas_font_for_drawing_state(state DrawingState, code_point u32) &platform.Font {
	if cascade := state.current_font_cascade_list {
		font := cascade.font_for_code_point_for_shaping(code_point)
		return &platform.Font{
			family: font.typeface.family_name
			point_size: font.point_size / 0.75
			weight: int(font.variations.weight)
			source_path:  font.typeface.source_path.clone()
			is_invisible: font.is_invisible
		}
	}
	font_text := state.font_string.trim_space()
	mut family := 'sans-serif'
	mut weight := 400
	if font_text.to_lower().contains('bold') {
		weight = 700
	} else {
		for field in font_text.fields() {
			if numeric_weight := strconv.atoi(field) {
				if numeric_weight >= 100 && numeric_weight <= 1000 {
					weight = numeric_weight
					break
				}
			}
		}
	}
	if pixel_end := font_text.index('px') {
		family_text := font_text[pixel_end + 2..].trim_space()
		if family_text != '' {
			family = family_text.split(',')[0].trim_space().trim('"\'')
		}
	}
	return &platform.Font{
		family: family
		point_size: f32(state.font_size_px)
		weight: weight
	}
}

fn canvas_text_run(state DrawingState, text string, initial_x f32) &platform.GlyphRun {
	code_points := text.runes()
	code_point := if code_points.len == 0 { u32(`A`) } else { u32(code_points[0]) }
	font := canvas_font_for_drawing_state(state, code_point)
	text_type := if state.direction == .rtl {
		platform.GlyphRunTextType.rtl
	} else {
		platform.GlyphRunTextType.ltr
	}
	return platform.shape_text(initial_x, f32(resolved_letter_spacing(state)), text, font, text_type)
}

fn canvas_text_run_for_canvas_state(state &CanvasState, text string, initial_x f32) &platform.GlyphRun {
	mut mutable_state := unsafe { &CanvasState(state) }
	refresh_canvas_font_cascade(mut mutable_state)
	return canvas_text_run(mutable_state.drawing_state, text, initial_x)
}

// The em square is as tall as the font size, divided at the alphabetic
// baseline in the same proportion as the font's ascent and descent.
fn canvas_em_square_ascent_and_descent(metrics platform.FontPixelMetrics) (f64, f64) {
	font_height := f64(metrics.ascent) + f64(metrics.descent)
	ascent := if font_height > 0 {
		f64(metrics.size) * f64(metrics.ascent) / font_height
	} else {
		f64(metrics.size) / 2.0
	}
	return ascent, f64(metrics.size) - ascent
}

// https://html.spec.whatwg.org/multipage/canvas.html#dom-context-2d-textbaseline
fn canvas_text_baseline_offset(baseline CanvasTextBaseline, metrics platform.FontPixelMetrics) f64 {
	em_ascent, em_descent := canvas_em_square_ascent_and_descent(metrics)
	return match baseline {
		.top { em_ascent }
		.hanging { f64(metrics.ascent) * 0.8 }
		.middle { (em_ascent - em_descent) / 2.0 }
		.alphabetic { 0.0 }
		.ideographic { -f64(metrics.descent) }
		.bottom { -em_descent }
	}
}

fn canvas_text_transform(state DrawingState, font &platform.Font, text_width f64,
	max_width ?f64) CanvasAffineTransform {
	mut transform := CanvasAffineTransform{}
	mut rendered_width := text_width
	if maximum := max_width {
		if text_width > maximum {
			horizontal_scale := maximum / text_width
			transform = CanvasAffineTransform{ a: horizontal_scale, d: 1 }
			rendered_width *= horizontal_scale
		}
	}
	mut alignment_offset := 0.0
	match state.text_align {
		.center {
			alignment_offset = -rendered_width / 2.0
		}
		.start {
			if state.direction == .rtl {
				alignment_offset = -rendered_width
			}
		}
		.end {
			if state.direction != .rtl {
				alignment_offset = -rendered_width
			}
		}
		.right {
			alignment_offset = -rendered_width
		}
		else {}
	}
	if alignment_offset != 0 {
		transform = canvas_transform_multiply(CanvasAffineTransform{ e: alignment_offset }, transform)
	}
	baseline_offset := canvas_text_baseline_offset(state.text_baseline, font.pixel_metrics())
	if baseline_offset != 0 {
		transform = canvas_transform_multiply(CanvasAffineTransform{ f: baseline_offset }, transform)
	}
	return transform
}

fn canvas_glyph_point(point platform.FontGlyphOutlinePoint, origin FloatPoint) FloatPoint {
	return FloatPoint{
		x: origin.x + f64(point.x)
		y: origin.y - f64(point.y)
	}
}

fn canvas_point_midpoint(first FloatPoint, second FloatPoint) FloatPoint {
	return FloatPoint{
		x: (first.x + second.x) / 2.0
		y: (first.y + second.y) / 2.0
	}
}

// Gfx::Path::glyph_run() expands TrueType quadratic contours for the outline
// fallback used by stroke text, maxWidth, shadows, and fallback-font runs.
fn append_canvas_glyph_contour(mut path CanvasGfxPath,
	contour []platform.FontGlyphOutlinePoint, origin FloatPoint) {
	if contour.len == 0 {
		return
	}
	first := contour[0]
	last := contour[contour.len - 1]
	mut start := FloatPoint{}
	mut first_index := 0
	mut point_count := contour.len
	if first.on_curve {
		start = canvas_glyph_point(first, origin)
		first_index = 1
		point_count--
	} else if last.on_curve {
		start = canvas_glyph_point(last, origin)
		point_count--
	} else {
		start = canvas_point_midpoint(canvas_glyph_point(last, origin), canvas_glyph_point(first, origin))
	}
	path.move_to(start)
	mut control := ?FloatPoint(none)
	for offset in 0 .. point_count {
		point := contour[(first_index + offset) % contour.len]
		mapped := canvas_glyph_point(point, origin)
		if point.on_curve {
			if previous_control := control {
				path.quadratic_bezier_curve_to(previous_control, mapped)
			} else {
				path.line_to(mapped)
			}
			control = none
		} else if previous_control := control {
			implied := canvas_point_midpoint(previous_control, mapped)
			path.quadratic_bezier_curve_to(previous_control, implied)
			control = mapped
		} else {
			control = mapped
		}
	}
	if final_control := control {
		path.quadratic_bezier_curve_to(final_control, start)
	}
	path.close()
}

fn canvas_glyph_run_path(run &platform.GlyphRun, baseline_y f64) CanvasGfxPath {
	mut path := CanvasGfxPath{}
	font := run.font()
	for glyph in run.glyphs() {
		outline := font.glyph_outline(glyph.glyph_index) or { continue }
		origin := FloatPoint{
			x: f64(glyph.position.x)
			y: baseline_y + f64(glyph.position.y)
		}
		for contour in outline.contours {
			append_canvas_glyph_contour(mut path, contour, origin)
		}
	}
	return path
}

// The compact bitmap renderer uses the binding enums as its native cap and join values.
$if test {
	fn to_gfx_cap(cap_style CanvasLineCap) CanvasLineCap {
		return cap_style
	}
}

$if test {
	fn to_gfx_join(join_style CanvasLineJoin) CanvasLineJoin {
		return join_style
	}
}

$if test {
	fn parse_fill_rule(fill_rule string) string {
		return if fill_rule == 'evenodd' { 'evenodd' } else { 'nonzero' }
	}
}

fn canvas_vector_angle(ux f64, uy f64, vx f64, vy f64) f64 {
	return math.atan2(ux * vy - uy * vx, ux * vx + uy * vy)
}

// Convert Gfx::Path's SVG endpoint-form elliptical arc to line segments for
// the software raster backend. This is the endpoint-to-center conversion used
// by SVG 2; it includes radii correction and preserves large-arc/sweep.
fn append_canvas_elliptical_arc(mut points []FloatPoint, start FloatPoint, segment PathSegment) {
	end := segment.point
	if start == end {
		return
	}
	mut radius_x := math.abs(segment.radii.width)
	mut radius_y := math.abs(segment.radii.height)
	if radius_x == 0 || radius_y == 0 {
		points << end
		return
	}
	cosine := math.cos(segment.x_axis_rotation)
	sine := math.sin(segment.x_axis_rotation)
	half_dx := (start.x - end.x) / 2.0
	half_dy := (start.y - end.y) / 2.0
	x1_prime := cosine * half_dx + sine * half_dy
	y1_prime := -sine * half_dx + cosine * half_dy
	radii_scale := x1_prime * x1_prime / (radius_x * radius_x) + y1_prime * y1_prime / (radius_y * radius_y)
	if radii_scale > 1.0 {
		scale := math.sqrt(radii_scale)
		radius_x *= scale
		radius_y *= scale
	}
	rx2 := radius_x * radius_x
	ry2 := radius_y * radius_y
	xp2 := x1_prime * x1_prime
	yp2 := y1_prime * y1_prime
	denominator := rx2 * yp2 + ry2 * xp2
	if denominator == 0 {
		points << end
		return
	}
	coefficient_sign := if segment.large_arc == segment.sweep { -1.0 } else { 1.0 }
	coefficient := coefficient_sign * math.sqrt(math.max(0.0, (rx2 * ry2 - rx2 * yp2 - ry2 * xp2) / denominator))
	cx_prime := coefficient * radius_x * y1_prime / radius_y
	cy_prime := coefficient * -radius_y * x1_prime / radius_x
	center_x := cosine * cx_prime - sine * cy_prime + (start.x + end.x) / 2.0
	center_y := sine * cx_prime + cosine * cy_prime + (start.y + end.y) / 2.0
	start_unit_x := (x1_prime - cx_prime) / radius_x
	start_unit_y := (y1_prime - cy_prime) / radius_y
	end_unit_x := (-x1_prime - cx_prime) / radius_x
	end_unit_y := (-y1_prime - cy_prime) / radius_y
	start_angle := canvas_vector_angle(1.0, 0.0, start_unit_x, start_unit_y)
	mut angle_delta := canvas_vector_angle(start_unit_x, start_unit_y, end_unit_x, end_unit_y)
	if !segment.sweep && angle_delta > 0 {
		angle_delta -= 2.0 * math.pi
	} else if segment.sweep && angle_delta < 0 {
		angle_delta += 2.0 * math.pi
	}
	// Keep the polygon's geometric error below roughly a quarter pixel while
	// retaining a useful minimum for small circles.
	max_radius := math.max(radius_x, radius_y)
	angular_steps := int(math.ceil(math.abs(angle_delta) / (math.pi / 16.0)))
	error_steps := int(math.ceil(math.abs(angle_delta) * math.sqrt(max_radius)))
	steps := math.min(4096, math.max(1, math.max(angular_steps, error_steps)))
	for index := 1; index <= steps; index++ {
		if index == steps {
			points << end
			continue
		}
		angle := start_angle + angle_delta * f64(index) / f64(steps)
		unit_x := radius_x * math.cos(angle)
		unit_y := radius_y * math.sin(angle)
		points << FloatPoint{
			x: center_x + cosine * unit_x - sine * unit_y
			y: center_y + sine * unit_x + cosine * unit_y
		}
	}
}

pub fn image_is_not_origin_clean(image CanvasImageSource) bool {
	return match image {
		DecodedImageCanvasSource {
			(image as DecodedImageCanvasSource).value.is_cors_cross_origin()
		}
		ImageBitmapCanvasSource { false }
	}
}

fn canvas_path_polygons_with_limit(path CanvasGfxPath, maximum_contours int) [][]FloatPoint {
	mut polygons := [][]FloatPoint{}
	mut points := []FloatPoint{}
	mut current := FloatPoint{}
	mut subpath_start := FloatPoint{}
	for segment in path.segments() {
		match segment.kind {
			.move_to {
				if points.len > 0 {
					polygons << points
					if maximum_contours > 0 && polygons.len >= maximum_contours {
						return polygons
					}
				}
				points = [segment.point]
				current = segment.point
				subpath_start = segment.point
			}
			.line_to {
				if points.len == 0 {
					points << current
				}
				points << segment.point
				current = segment.point
			}
			.quadratic_bezier_curve_to {
				start := current
				for step := 1; step <= 24; step++ {
					t := f64(step) / 24.0
					one_minus_t := 1.0 - t
					points << FloatPoint{
						x: one_minus_t * one_minus_t * start.x + 2.0 * one_minus_t * t * segment.control_point_0.x + t * t * segment.point.x
						y: one_minus_t * one_minus_t * start.y + 2.0 * one_minus_t * t * segment.control_point_0.y + t * t * segment.point.y
					}
				}
				current = segment.point
			}
			.cubic_bezier_curve_to {
				start := current
				for step := 1; step <= 32; step++ {
					t := f64(step) / 32.0
					u := 1.0 - t
					points << FloatPoint{
						x: u * u * u * start.x + 3.0 * u * u * t * segment.control_point_0.x + 3.0 * u * t * t * segment.control_point_1.x + t * t * t * segment.point.x
						y: u * u * u * start.y + 3.0 * u * u * t * segment.control_point_0.y + 3.0 * u * t * t * segment.control_point_1.y + t * t * t * segment.point.y
					}
				}
				current = segment.point
			}
			.elliptical_arc_to {
				append_canvas_elliptical_arc(mut points, current, segment)
				current = segment.point
			}
			.close_path {
				if points.len > 0 && points.last() != subpath_start {
					points << subpath_start
				}
				current = subpath_start
			}
		}
	}
	if points.len > 0 {
		polygons << points
	}
	return polygons
}

fn canvas_path_polygons(path CanvasGfxPath) [][]FloatPoint {
	return canvas_path_polygons_with_limit(path, 0)
}

// Convert the typed path emitted by CSS::BasicShapeStyleValue::to_path() into
// the same Gfx::Path-compatible segment model used by Path2D. Keeping the
// segments intact lets native painting retain curves and elliptical arcs;
// software hit testing consumes the flattened contours below.
pub fn canvas_gfx_path_from_style_value_path(path css.StyleValuePath) CanvasGfxPath {
	mut output := CanvasGfxPath{}
	for command in path.commands {
		point := FloatPoint{command.point.x().to_double(), command.point.y().to_double()}
		match command.type_ {
			.move_to {
				output.move_to(point)
			}
			.line_to {
				output.line_to(point)
			}
			.elliptical_arc_to {
				output.elliptical_arc_to(point, FloatSize{
					width: command.radii.width().to_double()
					height: command.radii.height().to_double()
				}, command.rotation, command.large_arc, command.sweep)
			}
			.close {
				output.close()
			}
			.svg_path {
				output.append_path(svg_path_to_canvas_gfx_path(svg.parse_path_data(command.svg_source)))
			}
		}
	}
	return output
}

// Gfx::Path::contains() operates on the retained curve path upstream. The
// compact software hit-test backend uses these adaptively subdivided contours;
// conversion happens once while constructing the paint tree, not per hit.
pub fn canvas_gfx_path_flattened_polygons(path CanvasGfxPath) [][]FloatPoint {
	return canvas_path_polygons(path)
}

// SkPathMeasure(path, false) consumes only the first contour. Expose a bounded
// version for SVG text-on-path so later contours are neither flattened nor
// allocated merely to be discarded.
pub fn canvas_gfx_path_first_contour_polyline(path CanvasGfxPath) []FloatPoint {
	polygons := canvas_path_polygons_with_limit(path, 1)
	return if polygons.len > 0 { polygons[0] } else { []FloatPoint{} }
}

fn canvas_path_bounds(path CanvasGfxPath) ?CanvasFloatRect {
	polygons := canvas_path_polygons(path)
	mut has_point := false
	mut min_x := 0.0
	mut min_y := 0.0
	mut max_x := 0.0
	mut max_y := 0.0
	for polygon in polygons {
		for point in polygon {
			if !has_point {
				min_x, max_x = point.x, point.x
				min_y, max_y = point.y, point.y
				has_point = true
			} else {
				min_x = math.min(min_x, point.x)
				min_y = math.min(min_y, point.y)
				max_x = math.max(max_x, point.x)
				max_y = math.max(max_y, point.y)
			}
		}
	}
	if !has_point {
		return none
	}
	return CanvasFloatRect{min_x, min_y, max_x - min_x, max_y - min_y}
}

fn canvas_point_in_polygon(points []FloatPoint, point FloatPoint) bool {
	if points.len < 3 {
		return false
	}
	mut inside := false
	mut previous := points[points.len - 1]
	for current in points {
		if (current.y > point.y) != (previous.y > point.y) {
			intersection_x := (previous.x - current.x) * (point.y - current.y) / (previous.y - current.y) + current.x
			if point.x < intersection_x {
				inside = !inside
			}
		}
		previous = current
	}
	return inside
}

fn canvas_winding_number(points []FloatPoint, point FloatPoint) int {
	if points.len < 3 {
		return 0
	}
	mut winding_number := 0
	mut previous := points[points.len - 1]
	for current in points {
		cross_product := (current.x - previous.x) * (point.y - previous.y) - (point.x - previous.x) * (current.y - previous.y)
		if previous.y <= point.y {
			if current.y > point.y && cross_product > 0 {
				winding_number++
			}
		} else if current.y <= point.y && cross_product < 0 {
			winding_number--
		}
		previous = current
	}
	return winding_number
}

fn is_point_in_path_internal(path CanvasGfxPath, transform CanvasAffineTransform, x f64, y f64, fill_rule string) bool {
	mut point := FloatPoint{x, y}
	if inverse := transform.inverse() {
		point = inverse.map(point)
	}
	polygons := canvas_path_polygons(path)
	if fill_rule == 'evenodd' {
		mut matches := 0
		for polygon in polygons {
			if canvas_point_in_polygon(polygon, point) {
				matches++
			}
		}
		return matches % 2 == 1
	}
	mut winding_number := 0
	for polygon in polygons {
		winding_number += canvas_winding_number(polygon, point)
	}
	return winding_number != 0
}

fn canvas_composite_operation_to_string(operation CompositingAndBlendingOperator) string {
	return match operation {
		.source_over { 'source-over' }
		.source_in { 'source-in' }
		.source_out { 'source-out' }
		.source_atop { 'source-atop' }
		.destination_over { 'destination-over' }
		.destination_in { 'destination-in' }
		.destination_out { 'destination-out' }
		.destination_atop { 'destination-atop' }
		.lighter { 'lighter' }
		.copy { 'copy' }
		.xor { 'xor' }
		.multiply { 'multiply' }
		.screen { 'screen' }
		.overlay { 'overlay' }
		.darken { 'darken' }
		.lighten { 'lighten' }
		.color_dodge { 'color-dodge' }
		.color_burn { 'color-burn' }
		.hard_light { 'hard-light' }
		.soft_light { 'soft-light' }
		.difference { 'difference' }
		.exclusion { 'exclusion' }
		.hue { 'hue' }
		.saturation { 'saturation' }
		.color { 'color' }
		.luminosity { 'luminosity' }
		.plus_darker { 'plus-darker' }
		.plus_lighter { 'plus-lighter' }
	}
}

fn canvas_composite_operation_from_string(value string) ?CompositingAndBlendingOperator {
	return match value {
		'normal', 'source-over' { .source_over }
		'source-in' { .source_in }
		'source-out' { .source_out }
		'source-atop' { .source_atop }
		'destination-over' { .destination_over }
		'destination-in' { .destination_in }
		'destination-out' { .destination_out }
		'destination-atop' { .destination_atop }
		'lighter' { .lighter }
		'copy' { .copy }
		'xor' { .xor }
		'multiply' { .multiply }
		'screen' { .screen }
		'overlay' { .overlay }
		'darken' { .darken }
		'lighten' { .lighten }
		'color-dodge' { .color_dodge }
		'color-burn' { .color_burn }
		'hard-light' { .hard_light }
		'soft-light' { .soft_light }
		'difference' { .difference }
		'exclusion' { .exclusion }
		'hue' { .hue }
		'saturation' { .saturation }
		'color' { .color }
		'luminosity' { .luminosity }
		'plus-darker' { .plus_darker }
		'plus-lighter' { .plus_lighter }
		else { none }
	}
}

fn canvas_color_to_string(color dom.Color) string {
	if color.a == 255 {
		return '#${color.r:02x}${color.g:02x}${color.b:02x}'
	}
	return 'rgba(${color.r}, ${color.g}, ${color.b}, ${f64(color.a) / 255.0})'
}

pub fn (context &OffscreenCanvasRenderingContext2D) canvas_element() &OffscreenCanvas {
	return context.canvas_
}

pub fn (context &OffscreenCanvasRenderingContext2D) painter() ?&dom.Bitmap_ {
	return context.canvas_.bitmap()
}

pub fn (context &OffscreenCanvasRenderingContext2D) global_composite_operation() string {
	return canvas_composite_operation_to_string(context.drawing_state.current_compositing_and_blending_operator)
}

pub fn (mut context OffscreenCanvasRenderingContext2D) set_global_composite_operation(value string) {
	operation := canvas_composite_operation_from_string(value) or { return }
	context.drawing_state.current_compositing_and_blending_operator = operation
}

pub fn (context &OffscreenCanvasRenderingContext2D) shadow_color() string {
	return canvas_color_to_string(context.drawing_state.shadow_color)
}

pub fn (mut context OffscreenCanvasRenderingContext2D) set_shadow_color(value string) {
	color := css.parse_color_string(value) or { return }
	context.drawing_state.shadow_color = dom.Color{color.r, color.g, color.b, color.a}
}

pub fn (context &OffscreenCanvasRenderingContext2D) filter() string {
	return context.drawing_state.filter_string or { 'none' }
}

fn canvas_filter_font(state DrawingState) &platform.Font {
	if state.font_style_value == none {
		// CanvasState.cpp lazily uses default_font(8) metrics for the initial 10px font.
		if platform.FontPlugin.is_initialized() {
			if font := platform.FontPlugin.the().default_font(8) {
				return &platform.Font{ ...font }
			}
		}
		return &platform.Font{ family: 'sans-serif', point_size: 8 }
	}
	if cascade := state.current_font_cascade_list {
		// FontCascadeList.cpp::first_available_font tests U+0020 unicode-range membership.
		for entry in cascade.fonts {
			if entry.unicode_ranges.len == 0 || entry.unicode_ranges.any(it.start <= 0x20 && 0x20 <= it.end) {
				return &platform.Font{ family: entry.font.typeface.family_name, point_size: entry.font.point_size / .75, weight: int(entry.font.variations.weight), source_path: entry.font.typeface.source_path }
			}
		}
		if cascade.last_resort_font != unsafe { nil } {
			font := cascade.last_resort_font
			return &platform.Font{ family: font.typeface.family_name, point_size: font.point_size / .75, weight: int(font.variations.weight), source_path: font.typeface.source_path }
		}
	}
	return canvas_font_for_drawing_state(state, u32(` `))
}

// CanvasState.cpp: font and root metrics both belong to the current canvas font.
fn (context &OffscreenCanvasRenderingContext2D) filter_computation_context(element ?&dom.Element) css.ComputationContext {
	state := context.drawing_state
	font := canvas_filter_font(state)
	metrics := font.pixel_metrics()
	font_metrics := css.LengthFontMetrics{
		font_size:    css.CSSPixels.nearest_value_for(state.font_size_px)
		x_height:     css.CSSPixels.nearest_value_for(metrics.x_height)
		cap_height:   css.CSSPixels.nearest_value_for(metrics.ascent)
		zero_advance: css.CSSPixels.nearest_value_for(metrics.advance_of_ascii_zero)
		// InitialValues::line_height() is zero (ComputedValues.h).
		line_height:  css.CSSPixels.new(0)
	}
	mut viewport := css.CSSPixelRect.new(0, 0, 0, 0)
	if canvas_element := element {
		if _ := canvas_element.navigable() {
			rect := canvas_element.document().viewport_rect()
			viewport = css.CSSPixelRect.new(rect.x, rect.y, rect.width, rect.height)
		}
	}
	return css.ComputationContext{
		length_resolution_context: css.LengthResolutionContext{
			viewport_rect:     viewport
			font_metrics:      font_metrics
			root_font_metrics: font_metrics
		}
		color_scheme:              css.PreferredColorScheme.light
	}
}

fn (mut context OffscreenCanvasRenderingContext2D) set_filter_internal(value string, element ?&dom.Element) {
	// Source clears the resolved filter before parsing, even when parsing fails.
	context.drawing_state.filter_functions = []
	if value == 'none' {
		context.drawing_state.filter_string = none
		return
	}
	mut parser := css.Parser.with_context(css.ParsingParams{
		value_context: [css.ValueParsingContext(css.SpecialContext.canvas_context_generic_value)]
	}, value)
	parsed := parser.parse_css_value(.filter) or { return }
	if parsed !is css.FilterValueListStyleValue { return }
	computation := context.filter_computation_context(element)
	absolutized := parsed.absolutized(computation)
	filter_list := if absolutized is css.FilterValueListStyleValue { absolutized } else { return }
	mut functions := []CanvasFilterFunction{}
	for item in filter_list.filter_value_list() {
		functions << match item {
			css.FilterOperationBlur {
				CanvasFilterFunction{ kind: .blur, amount: f32(item.resolved_radius()) }
			}
			css.FilterOperationColor {
				CanvasFilterFunction{ kind: .color, color_operation: item.operation, amount: f32(item.resolved_amount()) }
			}
			css.FilterOperationHueRotate {
				CanvasFilterFunction{ kind: .hue_rotate, amount: f32(item.angle_degrees()) }
			}
			css.FilterOperationDropShadow {
				mut color := canvas_color_black()
				if color_value := item.color {
					mut color_context := css.ColorResolutionContext{}
					mut can_resolve_color := true
					if canvas_element := element {
						can_resolve_color = false
						canvas_element.document().update_style_for_element(canvas_element, false)
						if canvas_element.el_computed_properties() != none {
							can_resolve_color = true
							abstract_element := dom.AbstractElement.new(canvas_element, none)
							color_context = css.ColorResolutionContext.for_element(&abstract_element)
						}
					}
					if can_resolve_color {
						if resolved := color_value.to_color(color_context) {
							color = dom.Color{resolved.r, resolved.g, resolved.b, resolved.a}
						}
					}
				}
				radius := if radius_value := item.radius {
					css.Length.from_style_value_logic(radius_value, none).absolute_length_to_px_without_rounding()
				} else {
					f64(0)
				}
				CanvasFilterFunction{
					kind:     .drop_shadow
					offset_x: f32(css.Length.from_style_value_logic(item.offset_x, none).absolute_length_to_px_without_rounding())
					offset_y: f32(css.Length.from_style_value_logic(item.offset_y, none).absolute_length_to_px_without_rounding())
					amount:   f32(radius)
					color:    color
				}
			}
			css.URL {
				// Keep the reference live: SVG resource mutations affect subsequent draws.
				if canvas_element := element {
					if reference := canvas_element.document().encoding_parse_and_serialize_url(item.url()) {
						CanvasFilterFunction{ kind: .svg_reference, reference: reference }
					} else { continue }
				} else { continue }
			}
		}
	}
	context.drawing_state.filter_functions = functions
	context.drawing_state.filter_string = value
}

pub fn (mut context OffscreenCanvasRenderingContext2D) set_filter(value string) {
	context.set_filter_internal(value, none)
}

pub fn (context &OffscreenCanvasRenderingContext2D) rect_path(x f64, y f64, width f64, height f64) CanvasGfxPath {
	mut path := CanvasGfxPath{}
	path.move_to(FloatPoint{x, y})
	path.line_to(FloatPoint{x + width, y})
	path.line_to(FloatPoint{x + width, y + height})
	path.line_to(FloatPoint{x, y + height})
	path.close()
	return path
}

pub fn (mut context OffscreenCanvasRenderingContext2D) fill_internal(path CanvasGfxPath, fill_rule string) {
	state := context.drawing_state
	style := state.fill_style.to_gfx_paint_style()
	if !style.is_visible() && state.current_compositing_and_blending_operator == .source_over {
		return
	}
	context.paint_shadow_for_fill_internal(path, fill_rule)
	context.paint_canvas_path(path, style, fill_rule, false, 0, state.global_alpha, state.transform)
}

pub fn (mut context OffscreenCanvasRenderingContext2D) stroke_internal(path CanvasGfxPath) {
	state := context.drawing_state
	style := state.stroke_style.to_gfx_paint_style()
	if !style.is_visible() && state.current_compositing_and_blending_operator == .source_over {
		return
	}
	context.paint_shadow_for_stroke_internal(path)
	context.paint_canvas_path(path, style, 'nonzero', true, 0, state.global_alpha, state.transform)
}

fn canvas_shadow_alpha(state DrawingState) f32 {
	mut alpha := f32(state.global_alpha) * (f32(state.shadow_color.a) / 255)
	// Upstream intentionally reads fill_style even while stroking a shadow.
	if color := state.fill_style.as_color() {
		if color.a > 0 { alpha = (f32(color.a) / 255) * f32(state.global_alpha) }
	}
	return alpha
}

pub fn (mut context OffscreenCanvasRenderingContext2D) paint_shadow_for_fill_internal(path CanvasGfxPath, fill_rule string) {
	state := context.drawing_state
	if state.shadow_blur == 0 && state.shadow_offset_x == 0 && state.shadow_offset_y == 0 { return }
	if state.current_compositing_and_blending_operator == .copy { return }
	alpha := canvas_shadow_alpha(state)
	if alpha == 0 { return }
	shadow := dom.Color{state.shadow_color.r, state.shadow_color.g, state.shadow_color.b, u8(math.round(f32(state.shadow_color.a) * alpha))}
	// Translate in output space, then multiply by the drawing-state transform.
	transform := canvas_transform_multiply(CanvasAffineTransform{ e: state.shadow_offset_x, f: state.shadow_offset_y }, state.transform)
	context.paint_canvas_path(path, FillOrStrokeStyle.from_color(shadow).to_gfx_paint_style(), fill_rule, false, state.shadow_blur, 1, transform)
}

pub fn (mut context OffscreenCanvasRenderingContext2D) paint_shadow_for_stroke_internal(path CanvasGfxPath) {
	state := context.drawing_state
	if state.current_compositing_and_blending_operator == .copy { return }
	if state.shadow_blur == 0 && state.shadow_offset_x == 0 && state.shadow_offset_y == 0 { return }
	alpha := canvas_shadow_alpha(state)
	if alpha == 0 { return }
	shadow := dom.Color{state.shadow_color.r, state.shadow_color.g, state.shadow_color.b, u8(math.round(f32(state.shadow_color.a) * alpha))}
	transform := canvas_transform_multiply(CanvasAffineTransform{ e: state.shadow_offset_x, f: state.shadow_offset_y }, state.transform)
	context.paint_canvas_path(path, FillOrStrokeStyle.from_color(shadow).to_gfx_paint_style(), 'nonzero', true, state.shadow_blur, 1, transform)
}
pub fn (mut context OffscreenCanvasRenderingContext2D) stroke() {
	context.stroke_internal(context.CanvasPath.path())
}

pub fn (mut context OffscreenCanvasRenderingContext2D) stroke_path(path &Path2D) {
	context.stroke_internal(path.path())
}

pub fn (mut context OffscreenCanvasRenderingContext2D) fill(fill_rule string) {
	context.fill_internal(context.CanvasPath.path(), fill_rule)
}

pub fn (mut context OffscreenCanvasRenderingContext2D) fill_path(path &Path2D, fill_rule string) {
	context.fill_internal(path.path(), fill_rule)
}

pub fn (mut context OffscreenCanvasRenderingContext2D) clip_internal(path CanvasGfxPath, fill_rule string) {
	context.drawing_state.clip_paths << CanvasClipPath{
		path: path.copy_transformed(context.drawing_state.transform)
		fill_rule: if fill_rule == 'evenodd' { 'evenodd' } else { 'nonzero' }
	}
}

pub fn (mut context OffscreenCanvasRenderingContext2D) clip(fill_rule string) {
	context.clip_internal(context.CanvasPath.path(), fill_rule)
}

pub fn (mut context OffscreenCanvasRenderingContext2D) clip_path(path &Path2D, fill_rule string) {
	context.clip_internal(path.path(), fill_rule)
}

pub fn (context &OffscreenCanvasRenderingContext2D) is_point_in_path(x f64, y f64, fill_rule string) bool {
	return is_point_in_path_internal(context.CanvasPath.path(), context.drawing_state.transform, x, y, fill_rule)
}

pub fn (context &OffscreenCanvasRenderingContext2D) is_point_in_path_with_path(path &Path2D, x f64, y f64, fill_rule string) bool {
	return is_point_in_path_internal(path.path(), context.drawing_state.transform, x, y, fill_rule)
}

pub fn (context &OffscreenCanvasRenderingContext2D) prepare_text(text string, max_width f64) PreparedCanvasText {
	if max_width <= 0 || math.is_nan(max_width) {
		return PreparedCanvasText{}
	}
	replaced := text.replace('\t', ' ').replace('\n', ' ').replace('\r', ' ').replace('\f', ' ')
	run := canvas_text_run_for_canvas_state(&context.CanvasState, replaced, 0)
	font := run.font()
	font_size := f64(font.point_size)
	mut width := f64(run.width())
	if width > max_width {
		width = max_width
	}
	mut x := 0.0
	match context.drawing_state.text_align {
		.center {
			x = -width / 2.0
		}
		.right, .end {
			x = -width
		}
		.start {
			if context.drawing_state.direction == .rtl {
				x = -width
			}
		}
		else {}
	}
	metrics := font.pixel_metrics()
	return PreparedCanvasText{
		text: replaced
		physical_x: x
		bounding_box: CanvasFloatRect{x, -f64(metrics.ascent), width, f64(metrics.ascent + metrics.descent)}
		font_size: font_size
	}
}

pub fn (context &OffscreenCanvasRenderingContext2D) font_cascade_list() string {
	return if context.drawing_state.font_string == '' {
		'10px sans-serif'
	} else {
		context.drawing_state.font_string
	}
}

pub fn (context &OffscreenCanvasRenderingContext2D) text_path(text string, x f64, y f64, max_width ?f64) CanvasGfxPath {
	if maximum := max_width {
		if maximum <= 0 {
			return CanvasGfxPath{}
		}
	}
	replaced := text.replace('\t', ' ').replace('\n', ' ').replace('\r', ' ').replace('\f', ' ')
	run := canvas_text_run_for_canvas_state(&context.CanvasState, replaced, f32(x))
	path := canvas_glyph_run_path(run, y)
	return path.copy_transformed(canvas_text_transform(context.drawing_state, run.font(), f64(run.width()), max_width))
}

pub fn (mut context OffscreenCanvasRenderingContext2D) fill_text(text string, x f64, y f64, max_width ?f64) {
	context.fill_canvas_text(text, x, y, max_width)
}

fn (mut context OffscreenCanvasRenderingContext2D) fill_canvas_text(text string, x f64, y f64, max_width ?f64) bool {
	if !is_finite(x) || !is_finite(y) { return false }
	if max_width_value := max_width {
		if !is_finite(max_width_value) {
			return false
		}
	}
	state := context.drawing_state
	if max_width != none || state.shadow_blur != 0 || state.shadow_offset_x != 0 || state.shadow_offset_y != 0 {
		path := context.text_path(text, x, y, max_width)
		context.fill_internal(path, 'nonzero')
		return canvas_path_bounds(path) != none
	}
	replaced := text.replace('\t', ' ').replace('\n', ' ').replace('\r', ' ').replace('\f', ' ')
	run := canvas_text_run_for_canvas_state(&context.CanvasState, replaced, 0)
	if run.font().is_invisible {
		path := context.text_path(text, x, y, max_width)
		context.fill_internal(path, 'nonzero')
		return canvas_path_bounds(path) != none
	}
	translation := canvas_text_transform(context.drawing_state, run.font(), f64(run.width()), none).map(FloatPoint{x, y})
	return context.paint_canvas_glyph_run(run, translation)
}

pub fn (mut context OffscreenCanvasRenderingContext2D) stroke_text(text string, x f64, y f64, max_width ?f64) {
	if !is_finite(x) || !is_finite(y) { return }
	if max_width_value := max_width {
		if !is_finite(max_width_value) {
			return
		}
	}
	context.stroke_internal(context.text_path(text, x, y, max_width))
}

pub fn (context &OffscreenCanvasRenderingContext2D) clear_color() dom.Color {
	return if context.context_attributes.alpha {
		canvas_color_transparent()
	} else {
		canvas_color_black()
	}
}

pub fn (mut context OffscreenCanvasRenderingContext2D) put_pixels_from_an_image_data_onto_a_bitmap(image_data &ImageData, dx int, dy int, dirty_x int, dirty_y int, dirty_width int, dirty_height int) {
	context.put_image_data_dirty(image_data, dx, dy, dirty_x, dirty_y, dirty_width, dirty_height)
}

// HTML canvas-specific boundaries. Rendering itself is shared with the
// offscreen implementation, while invalidation remains element-owned.
pub fn (context &CanvasRenderingContext2D) canvas_element() &dom.HTMLCanvasElement {
	return context.element
}

pub fn (mut context CanvasRenderingContext2D) set_size(width u32, height u32) {
	context.OffscreenCanvasRenderingContext2D.set_size(width, height)
}

pub fn (mut context CanvasRenderingContext2D) did_draw(rect CanvasFloatRect) {
	_ = rect
	html_canvas_element_set_canvas_content_dirty(context.element) or {}

	// NB: Don't request a display list recording here: the new content reaches the compositor through the canvas
	// surface registry when the canvas is presented, and the cached DrawCanvas command is invalidated when the
	// content generation moves in prepare_for_compositing.
	mut element_node := unsafe { &dom.Node(context.element.as_node()) }
	element_node.set_needs_repaint(.no)
}

pub fn (context &CanvasRenderingContext2D) painter() ?&dom.Bitmap_ {
	return context.OffscreenCanvasRenderingContext2D.painter()
}

pub fn (context &CanvasRenderingContext2D) allocate_painting_surface_if_needed() {
	_ = context.OffscreenCanvasRenderingContext2D.painter()
}

pub fn (mut context CanvasRenderingContext2D) reset_to_default_state() {
	context.OffscreenCanvasRenderingContext2D.reset_to_default_state()
}

pub fn (context &CanvasRenderingContext2D) create_image_data(width int, height int, settings ?ImageDataSettings) !&ImageData {
	return context.OffscreenCanvasRenderingContext2D.create_image_data(width, height, settings)
}

pub fn (context &CanvasRenderingContext2D) create_image_data_from(source &ImageData) !&ImageData {
	return context.OffscreenCanvasRenderingContext2D.create_image_data_from(source)
}

pub fn (context &CanvasRenderingContext2D) get_image_data(x int, y int, width int, height int, settings ?ImageDataSettings) !&ImageData {
	return context.OffscreenCanvasRenderingContext2D.get_image_data(x, y, width, height, settings)
}

pub fn (mut context CanvasRenderingContext2D) put_image_data(image_data &ImageData, x int, y int) {
	context.OffscreenCanvasRenderingContext2D.put_image_data(image_data, x, y)
	context.did_draw(CanvasFloatRect{f64(x), f64(y), f64(image_data.width()), f64(image_data.height())})
}

pub fn (mut context CanvasRenderingContext2D) put_image_data_dirty(image_data &ImageData, x int, y int, dirty_x int, dirty_y int, dirty_width int, dirty_height int) {
	context.OffscreenCanvasRenderingContext2D.put_image_data_dirty(image_data, x, y, dirty_x, dirty_y, dirty_width, dirty_height)
	context.did_draw(CanvasFloatRect{f64(x + dirty_x), f64(y + dirty_y), f64(dirty_width), f64(dirty_height)})
}

pub fn (context &CanvasRenderingContext2D) measure_text(value string) &TextMetrics {
	return context.OffscreenCanvasRenderingContext2D.measure_text(value)
}

pub fn (context &CanvasRenderingContext2D) image_smoothing_enabled() bool {
	return context.OffscreenCanvasRenderingContext2D.image_smoothing_enabled()
}

pub fn (mut context CanvasRenderingContext2D) set_image_smoothing_enabled(value bool) {
	context.OffscreenCanvasRenderingContext2D.set_image_smoothing_enabled(value)
}

pub fn (context &CanvasRenderingContext2D) image_smoothing_quality() ImageSmoothingQuality {
	return context.OffscreenCanvasRenderingContext2D.image_smoothing_quality()
}

pub fn (mut context CanvasRenderingContext2D) set_image_smoothing_quality(value ImageSmoothingQuality) {
	context.OffscreenCanvasRenderingContext2D.set_image_smoothing_quality(value)
}

pub fn (context &CanvasRenderingContext2D) global_alpha() f64 {
	return context.OffscreenCanvasRenderingContext2D.global_alpha()
}

pub fn (mut context CanvasRenderingContext2D) set_global_alpha(value f64) {
	context.OffscreenCanvasRenderingContext2D.set_global_alpha(value)
}

pub fn (context &CanvasRenderingContext2D) shadow_offset_x() f64 {
	return context.OffscreenCanvasRenderingContext2D.shadow_offset_x()
}

pub fn (mut context CanvasRenderingContext2D) set_shadow_offset_x(value f64) {
	context.OffscreenCanvasRenderingContext2D.set_shadow_offset_x(value)
}

pub fn (context &CanvasRenderingContext2D) shadow_offset_y() f64 {
	return context.OffscreenCanvasRenderingContext2D.shadow_offset_y()
}

pub fn (mut context CanvasRenderingContext2D) set_shadow_offset_y(value f64) {
	context.OffscreenCanvasRenderingContext2D.set_shadow_offset_y(value)
}

pub fn (context &CanvasRenderingContext2D) shadow_blur() f64 {
	return context.OffscreenCanvasRenderingContext2D.shadow_blur()
}

pub fn (mut context CanvasRenderingContext2D) set_shadow_blur(value f64) {
	context.OffscreenCanvasRenderingContext2D.set_shadow_blur(value)
}

pub fn (context &CanvasRenderingContext2D) rect_path(x f64, y f64, width f64, height f64) CanvasGfxPath {
	return context.OffscreenCanvasRenderingContext2D.rect_path(x, y, width, height)
}

pub fn (context &CanvasRenderingContext2D) clear_color() dom.Color {
	return context.OffscreenCanvasRenderingContext2D.clear_color()
}

pub fn (context &CanvasRenderingContext2D) font_cascade_list() string {
	return context.OffscreenCanvasRenderingContext2D.font_cascade_list()
}

pub fn (context &CanvasRenderingContext2D) font() string {
	return context.OffscreenCanvasRenderingContext2D.font()
}

pub fn (mut context CanvasRenderingContext2D) set_font(font string) {
	context.OffscreenCanvasRenderingContext2D.set_font(font)
}

pub fn (context &CanvasRenderingContext2D) prepare_text(text string, max_width f64) PreparedCanvasText {
	return context.OffscreenCanvasRenderingContext2D.prepare_text(text, max_width)
}

pub fn (context &CanvasRenderingContext2D) text_path(text string, x f64, y f64, max_width ?f64) CanvasGfxPath {
	return context.OffscreenCanvasRenderingContext2D.text_path(text, x, y, max_width)
}

pub fn (mut context CanvasRenderingContext2D) stroke_internal(path CanvasGfxPath) {
	context.OffscreenCanvasRenderingContext2D.stroke_internal(path)
	if bounds := canvas_path_bounds(path) {
		context.did_draw(bounds)
	}
}

pub fn (mut context CanvasRenderingContext2D) fill_internal(path CanvasGfxPath, fill_rule string) {
	context.OffscreenCanvasRenderingContext2D.fill_internal(path, fill_rule)
	if bounds := canvas_path_bounds(path) {
		context.did_draw(bounds)
	}
}

pub fn (mut context CanvasRenderingContext2D) clip_internal(path CanvasGfxPath, fill_rule string) {
	context.OffscreenCanvasRenderingContext2D.clip_internal(path, fill_rule)
}

pub fn (context &CanvasRenderingContext2D) is_point_in_path(x f64, y f64, fill_rule string) bool {
	return context.OffscreenCanvasRenderingContext2D.is_point_in_path(x, y, fill_rule)
}

pub fn (mut context CanvasRenderingContext2D) paint_shadow_for_fill_internal(path CanvasGfxPath, fill_rule string) {
	context.OffscreenCanvasRenderingContext2D.paint_shadow_for_fill_internal(path, fill_rule)
}

pub fn (mut context CanvasRenderingContext2D) paint_shadow_for_stroke_internal(path CanvasGfxPath) {
	context.OffscreenCanvasRenderingContext2D.paint_shadow_for_stroke_internal(path)
}

pub fn (mut context CanvasRenderingContext2D) fill_rect(x f64, y f64, width f64, height f64) {
	path := context.rect_path(x, y, width, height)
	context.fill_internal(path, 'evenodd')
}

pub fn (mut context CanvasRenderingContext2D) clear_rect(x f64, y f64, width f64, height f64) {
	context.OffscreenCanvasRenderingContext2D.clear_rect(x, y, width, height)
	context.did_draw(CanvasFloatRect{x, y, width, height})
}

pub fn (mut context CanvasRenderingContext2D) stroke_rect(x f64, y f64, width f64, height f64) {
	context.stroke_internal(context.rect_path(x, y, width, height))
}

pub fn (mut context CanvasRenderingContext2D) begin_path() {
	context.OffscreenCanvasRenderingContext2D.begin_path()
}

pub fn (mut context CanvasRenderingContext2D) stroke() {
	context.stroke_internal(context.OffscreenCanvasRenderingContext2D.CanvasPath.path())
}

pub fn (mut context CanvasRenderingContext2D) stroke_path(path &Path2D) {
	context.stroke_internal(path.path())
}

pub fn (mut context CanvasRenderingContext2D) fill(fill_rule string) {
	context.fill_internal(context.OffscreenCanvasRenderingContext2D.CanvasPath.path(), fill_rule)
}

pub fn (mut context CanvasRenderingContext2D) fill_path(path &Path2D, fill_rule string) {
	context.fill_internal(path.path(), fill_rule)
}

pub fn (mut context CanvasRenderingContext2D) fill_text(text string, x f64, y f64, max_width ?f64) {
	if context.OffscreenCanvasRenderingContext2D.fill_canvas_text(text, x, y, max_width) {
		context.did_draw(CanvasFloatRect{})
	}
}

pub fn (mut context CanvasRenderingContext2D) stroke_text(text string, x f64, y f64, max_width ?f64) {
	if !is_finite(x) || !is_finite(y) { return }
	if maximum := max_width { if !is_finite(maximum) { return } }
	context.stroke_internal(context.text_path(text, x, y, max_width))
}

pub fn (mut context CanvasRenderingContext2D) clip(fill_rule string) {
	context.clip_internal(context.OffscreenCanvasRenderingContext2D.CanvasPath.path(), fill_rule)
}

pub fn (mut context CanvasRenderingContext2D) clip_path(path &Path2D, fill_rule string) {
	context.clip_internal(path.path(), fill_rule)
}

pub fn (context &CanvasRenderingContext2D) global_composite_operation() string {
	return context.OffscreenCanvasRenderingContext2D.global_composite_operation()
}

pub fn (mut context CanvasRenderingContext2D) set_global_composite_operation(value string) {
	context.OffscreenCanvasRenderingContext2D.set_global_composite_operation(value)
}

pub fn (context &CanvasRenderingContext2D) shadow_color() string {
	return context.OffscreenCanvasRenderingContext2D.shadow_color()
}

pub fn (mut context CanvasRenderingContext2D) set_shadow_color(value string) {
	context.OffscreenCanvasRenderingContext2D.set_shadow_color(value)
}

pub fn (context &CanvasRenderingContext2D) filter() string {
	return context.OffscreenCanvasRenderingContext2D.filter()
}

pub fn (mut context CanvasRenderingContext2D) set_filter(value string) {
	context.OffscreenCanvasRenderingContext2D.set_filter_internal(value,unsafe { &dom.Element(context.element) })
}

pub fn (mut context CanvasRenderingContext2D) draw_image_internal(request CanvasDrawImageRequest) ! {
	context.OffscreenCanvasRenderingContext2D.draw_image_internal(request)!
	context.did_draw(CanvasFloatRect{
		x: request.destination_x
		y: request.destination_y
		width: request.destination_width
		height: request.destination_height
	})
}

pub fn (mut context CanvasRenderingContext2D) put_pixels_from_an_image_data_onto_a_bitmap(image_data &ImageData, dx int, dy int, dirty_x int, dirty_y int, dirty_width int, dirty_height int) {
	context.OffscreenCanvasRenderingContext2D.put_pixels_from_an_image_data_onto_a_bitmap(image_data, dx, dy, dirty_x, dirty_y, dirty_width, dirty_height)
	context.did_draw(CanvasFloatRect{f64(dx + dirty_x), f64(dy + dirty_y), f64(dirty_width), f64(dirty_height)})
}
