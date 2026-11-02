module painting

import css
import math

pub enum BackgroundAttachment {
	fixed
	local
	scroll
}

pub enum BackgroundBoxKind {
	border_box
	padding_box
	content_box
	text
}

pub enum Repetition {
	repeat
	space
	round
	no_repeat
}

pub struct BackgroundBox {
pub mut:
	rect  Rect
	radii BorderRadiiData
}

pub fn (mut box BackgroundBox) shrink(top f64, right f64, bottom f64, left f64) {
	box.rect = box.rect.inflated(-top, -right, -bottom, -left)
	box.radii.shrink(top, right, bottom, left)
}

pub struct ResolvedBackgroundLayer {
pub:
	image_id                    string
	attachment                  BackgroundAttachment
	clip                        BackgroundBoxKind
	position_x                  f64
	position_y                  f64
	background_positioning_area Rect
	image_rect                  Rect
	repeat_x                    Repetition
	repeat_y                    Repetition
	blend_mode                  BlendMode
}

pub struct ResolvedBackground {
pub:
	color_box       BackgroundBox
	layers          []ResolvedBackgroundLayer
	needs_text_clip bool
	background_rect Rect
	color           Color
}

pub fn background_box_for_kind(kind BackgroundBoxKind, border_box BackgroundBox,
	metrics BoxModelMetrics) BackgroundBox {
	mut result := border_box
	match kind {
		.content_box {
			result.shrink(metrics.padding.top, metrics.padding.right, metrics.padding.bottom, metrics.padding.left)
			result.shrink(metrics.border.top, metrics.border.right, metrics.border.bottom, metrics.border.left)
		}
		.padding_box {
			result.shrink(metrics.border.top, metrics.border.right, metrics.border.bottom, metrics.border.left)
		}
		else {}
	}
	return result
}

pub struct BackgroundLayerResolutionInput {
pub:
	layer                       css.BackgroundLayerData
	image_id                    string
	natural_width               f64
	natural_height              f64
	background_positioning_area Rect
	resolution_context          css.LengthResolutionContext
}

pub struct BackgroundLayerWithoutIntrinsicResolutionInput {
pub:
	layer                       css.BackgroundLayerData
	image_id                    string
	background_positioning_area Rect
	resolution_context          css.LengthResolutionContext
}

fn background_attachment_from_css(attachment css.BackgroundAttachment) BackgroundAttachment {
	return match attachment {
		.fixed { .fixed }
		.local { .local }
		.scroll { .scroll }
	}
}

fn background_box_from_css(box css.BackgroundBox) BackgroundBoxKind {
	return match box {
		.border_box { .border_box }
		.padding_box { .padding_box }
		.content_box { .content_box }
		.text { .text }
	}
}

fn repetition_from_css(repetition css.Repetition) Repetition {
	return match repetition {
		.repeat { .repeat }
		.space { .space }
		.round { .round }
		.no_repeat { .no_repeat }
	}
}

pub fn blend_mode_from_css(mode css.MixBlendMode) BlendMode {
	return match mode {
		.normal { .normal }
		.multiply { .multiply }
		.screen { .screen }
		.overlay { .overlay }
		.darken { .darken }
		.lighten { .lighten }
		.color_dodge { .color_dodge }
		.color_burn { .color_burn }
		.hard_light { .hard_light }
		.soft_light { .soft_light }
		.difference { .difference }
		.exclusion { .exclusion }
		.hue { .hue }
		.saturation { .saturation }
		.color { .color }
		.luminosity { .luminosity }
		.plus_darker { .plus_darker }
		.plus_lighter { .plus_lighter }
	}
}

// The per-layer body of BackgroundPainting.cpp's resolve_background_layers().
// Image decoding is a renderer responsibility in the V shell, so natural image
// dimensions enter here after decode; all CSS sizing, round-repeat correction,
// aspect-ratio restoration, and position resolution retain the source order.
pub fn resolve_background_layer(input BackgroundLayerResolutionInput) ?ResolvedBackgroundLayer {
	if input.natural_width <= 0 || input.natural_height <= 0 {
		return none
	}
	natural_width := css.CSSPixels.nearest_value_for(input.natural_width)
	natural_height := css.CSSPixels.nearest_value_for(input.natural_height)
	return resolve_background_layer_with_natural_size(input.layer, input.image_id, input.background_positioning_area, input.resolution_context, css.SizeWithAspectRatio{
		width: natural_width
		height: natural_height
		aspect_ratio: css.CSSPixelFraction.new(natural_width, natural_height)
	})
}

// CSS gradients have neither natural dimensions nor a natural aspect ratio. Keep that absence
// explicit when running CSS Images' default sizing algorithm: substituting the positioning area as
// a fake intrinsic bitmap size gives the wrong result when only one background-size axis is auto.
pub fn resolve_background_layer_without_intrinsic(input BackgroundLayerWithoutIntrinsicResolutionInput) ?ResolvedBackgroundLayer {
	return resolve_background_layer_with_natural_size(input.layer, input.image_id, input.background_positioning_area, input.resolution_context, css.SizeWithAspectRatio{})
}

// Preserve optional SVG dimensions and aspect ratio through default sizing.
pub fn resolve_background_layer_with_natural_size(layer css.BackgroundLayerData, image_id string,
	area Rect, resolution_context css.LengthResolutionContext,
	natural_size css.SizeWithAspectRatio) ?ResolvedBackgroundLayer {
	area_width := css.CSSPixels.nearest_value_for(area.width)
	area_height := css.CSSPixels.nearest_value_for(area.height)
	mut specified_width := ?css.CSSPixels(none)
	mut specified_height := ?css.CSSPixels(none)
	if layer.size_type == .length_percentage {
		if !layer.size_x.is_auto() {
			specified_width = layer.size_x.length_percentage().to_px(resolution_context, area_width)
		}
		if !layer.size_y.is_auto() {
			specified_height = layer.size_y.length_percentage().to_px(resolution_context, area_height)
		}
	}
	concrete_size := css.run_default_sizing_algorithm(specified_width, specified_height, natural_size, css.CSSPixelSize.new(area_width, area_height))
	concrete_width := concrete_size.width()
	concrete_height := concrete_size.height()
	if concrete_width.raw_value() <= 0 || concrete_height.raw_value() <= 0 {
		return none
	}

	mut image_width := concrete_width
	mut image_height := concrete_height
	match layer.size_type {
		.contain {
			ratio := math.min(area_width.to_double() / concrete_width.to_double(), area_height.to_double() / concrete_height.to_double())
			image_width = concrete_width.scaled(ratio)
			image_height = concrete_height.scaled(ratio)
		}
		.cover {
			ratio := math.max(area_width.to_double() / concrete_width.to_double(), area_height.to_double() / concrete_height.to_double())
			image_width = concrete_width.scaled(ratio)
			image_height = concrete_height.scaled(ratio)
		}
		.length_percentage {}
	}
	if image_width.raw_value() <= 0 || image_height.raw_value() <= 0 {
		return none
	}

	if layer.repeat_x == .round || layer.repeat_y == .round {
		if layer.repeat_x == .round {
			count := round_background_repeat_count(area_width, image_width)
			image_width = area_width.divided_by(count).to_css_pixels()
		}
		if layer.repeat_y == .round {
			count := round_background_repeat_count(area_height, image_height)
			image_height = area_height.divided_by(count).to_css_pixels()
		}
		if layer.repeat_x != layer.repeat_y {
			if layer.size_x.is_auto() {
				image_width = image_height.times_fraction(concrete_width.divided_by(concrete_height))
			}
			if layer.size_y.is_auto() {
				image_height = image_width.times_fraction(concrete_height.divided_by(concrete_width))
			}
		}
	}
	if image_width.raw_value() <= 0 || image_height.raw_value() <= 0 {
		return none
	}
	space_x := area_width.minus(image_width)
	space_y := area_height.minus(image_height)
	position_x := layer.position_x.to_px(resolution_context, space_x)
	position_y := layer.position_y.to_px(resolution_context, space_y)
	return ResolvedBackgroundLayer{
		image_id: image_id
		attachment: background_attachment_from_css(layer.attachment)
		clip: background_box_from_css(layer.clip)
		position_x: position_x.to_double()
		position_y: position_y.to_double()
		background_positioning_area: area
		image_rect: Rect{0, 0, image_width.to_double(), image_height.to_double()}
		repeat_x: repetition_from_css(layer.repeat_x)
		repeat_y: repetition_from_css(layer.repeat_y)
		blend_mode: blend_mode_from_css(layer.blend_mode)
	}
}

// BackgroundPainting.cpp first converts the width ratio to CSSPixels, rounds
// that fixed-point value to an integer CSS pixel, and only then divides the
// positioning area. Preserve that order instead of rounding an f64 ratio.
fn round_background_repeat_count(area_length css.CSSPixels,
	image_length css.CSSPixels) css.CSSPixels {
	ratio := area_length.divided_by(image_length).to_css_pixels()
	rounded := css.css_pixels_round(ratio)
	if rounded.raw_value() <= 0 {
		return css.CSSPixels.new(1)
	}
	return rounded
}

struct BackgroundRepetitionAxis {
	repeats bool
	has_gap bool
	step    css.CSSPixels
}

fn background_repetition_axis(mode Repetition, area_length css.CSSPixels,
	image_length css.CSSPixels, uses_float_modulo bool) BackgroundRepetitionAxis {
	if image_length.raw_value() <= 0 {
		return BackgroundRepetitionAxis{}
	}
	return match mode {
		.round {
			BackgroundRepetitionAxis{true, false, image_length}
		}
		.repeat {
			BackgroundRepetitionAxis{true, false, image_length}
		}
		.no_repeat {
			BackgroundRepetitionAxis{false, false, image_length}
		}
		.space {
			whole_images := area_length.divided_by(image_length).to_int()
			if whole_images <= 1 {
				BackgroundRepetitionAxis{false, false, image_length}
			} else {
				// BackgroundPainting.cpp preserves an observable implementation quirk:
				// horizontal spacing uses doubles, while vertical spacing passes floats
				// to fmod. Round both operands and the result through f32 on that path.
				space := if uses_float_modulo {
					f64(f32(math.mod(f64(area_length.to_float()), f64(image_length.to_float()))))
				} else {
					math.mod(area_length.to_double(), image_length.to_double())
				}
				gap := css.CSSPixels.nearest_value_for(space / f64(whole_images - 1))
				BackgroundRepetitionAxis{true, true, image_length.plus(gap)}
			}
		}
	}
}

pub struct BackgroundTilePlan {
pub:
	first_tile       Rect
	repeat_x         bool
	repeat_y         bool
	repeat_x_has_gap bool
	repeat_y_has_gap bool
	x_step           f64
	y_step           f64
}

pub fn (plan BackgroundTilePlan) can_use_repeated_bitmap() bool {
	return (plan.repeat_x || plan.repeat_y) && !plan.repeat_x_has_gap
		&& !plan.repeat_y_has_gap
}

fn first_visible_background_tile_position(start css.CSSPixels, step css.CSSPixels,
	clip_start css.CSSPixels, repeats bool) css.CSSPixels {
	if !repeats || start.compare(clip_start) <= 0 || step.raw_value() <= 0 {
		return start
	}
	// This deliberately follows BackgroundPainting.cpp's fixed-point operator
	// order: ceil the CSSPixels conversion of the fraction, multiply, then floor.
	ratio := start.minus(clip_start).divided_by(step).to_css_pixels()
	delta := css.css_pixels_floor(step.times(css.css_pixels_ceil(ratio)))
	return start.minus(delta)
}

pub fn background_tile_plan(layer ResolvedBackgroundLayer, scroll_offset Point,
	clip Rect) BackgroundTilePlan {
	mut area_x := css.CSSPixels.nearest_value_for(layer.background_positioning_area.x)
	mut area_y := css.CSSPixels.nearest_value_for(layer.background_positioning_area.y)
	area_width := css.CSSPixels.nearest_value_for(layer.background_positioning_area.width)
	area_height := css.CSSPixels.nearest_value_for(layer.background_positioning_area.height)
	match layer.attachment {
		.local {
			area_x = area_x.minus(css.CSSPixels.nearest_value_for(scroll_offset.x))
			area_y = area_y.minus(css.CSSPixels.nearest_value_for(scroll_offset.y))
		}
		.fixed, .scroll {}
	}
	image_width := css.CSSPixels.nearest_value_for(layer.image_rect.width)
	image_height := css.CSSPixels.nearest_value_for(layer.image_rect.height)
	x_axis := background_repetition_axis(layer.repeat_x, area_width, image_width, false)
	y_axis := background_repetition_axis(layer.repeat_y, area_height, image_height, true)
	base_x := area_x.plus(css.CSSPixels.nearest_value_for(layer.position_x))
	base_y := area_y.plus(css.CSSPixels.nearest_value_for(layer.position_y))
	start_x := first_visible_background_tile_position(base_x, x_axis.step, css.CSSPixels.nearest_value_for(clip.left()), x_axis.repeats)
	start_y := first_visible_background_tile_position(base_y, y_axis.step, css.CSSPixels.nearest_value_for(clip.top()), y_axis.repeats)
	return BackgroundTilePlan{
		first_tile: Rect{start_x.to_double(), start_y.to_double(), image_width.to_double(), image_height.to_double()}
		repeat_x: x_axis.repeats
		repeat_y: y_axis.repeats
		repeat_x_has_gap: x_axis.has_gap
		repeat_y_has_gap: y_axis.has_gap
		x_step: x_axis.step.to_double()
		y_step: y_axis.step.to_double()
	}
}

// background_tiles resolves attachment, position and repetition into concrete
// destination rectangles. Clipping remains a display-list operation.
pub fn background_tiles(layer ResolvedBackgroundLayer, scroll_offset Point, clip Rect) []Rect {
	return background_tiles_limited(layer, scroll_offset, clip, 0)
}

// The display-list player normally uses a dedicated repeated-bitmap command.
// Compatibility renderers can bound their materialized tile list while still
// sharing the exact positioning and stepping algorithm; zero means unlimited.
pub fn background_tiles_limited(layer ResolvedBackgroundLayer, scroll_offset Point,
	clip Rect, maximum_tiles int) []Rect {
	plan := background_tile_plan(layer, scroll_offset, clip)
	return background_tiles_from_plan_limited(plan, clip, maximum_tiles)
}

pub fn background_tiles_from_plan_limited(plan BackgroundTilePlan, clip Rect,
	maximum_tiles int) []Rect {
	if plan.first_tile.width <= 0 || plan.first_tile.height <= 0 {
		return []Rect{}
	}
	mut tiles := []Rect{}
	mut y := plan.first_tile.y
	for y < clip.bottom() {
		mut x := plan.first_tile.x
		for x < clip.right() {
			tile := Rect{x, y, plan.first_tile.width, plan.first_tile.height}
			if tile.intersects(clip) {
				tiles << tile
				if maximum_tiles > 0 && tiles.len >= maximum_tiles {
					return tiles
				}
			}
			if !plan.repeat_x {
				break
			}
			x += plan.x_step
		}
		if !plan.repeat_y {
			break
		}
		y += plan.y_step
	}
	return tiles
}

const border_dark_light_absolute_value_difference = 1.0 / 3.0

fn color_hsv(color Color) (f64, f64, f64) {
	r := f64(color.r) / 255.0
	g := f64(color.g) / 255.0
	b := f64(color.b) / 255.0
	maximum := math.max(math.max(r, g), b)
	minimum := math.min(math.min(r, g), b)
	chroma := maximum - minimum
	mut hue := 0.0
	if chroma != 0 {
		if maximum == r {
			hue = 60.0 * (g - b) / chroma + 360.0
		} else if maximum == g {
			hue = 60.0 * (b - r) / chroma + 120.0
		} else {
			hue = 60.0 * (r - g) / chroma + 240.0
		}
		if hue >= 360.0 {
			hue -= 360.0
		}
	}
	saturation := if maximum == 0 { 0.0 } else { chroma / maximum }
	return hue, saturation, maximum
}

fn color_from_hsv(hue f64, saturation f64, value f64, alpha u8) Color {
	high := int(hue / 60.0) % 6
	fraction := hue / 60.0 - f64(high)
	c1 := value * (1.0 - saturation)
	c2 := value * (1.0 - saturation * fraction)
	c3 := value * (1.0 - saturation * (1.0 - fraction))
	mut r := 0.0
	mut g := 0.0
	mut b := 0.0
	match high {
		0 {
			r = value
			g = c3
			b = c1
		}
		1 {
			r = c2
			g = value
			b = c1
		}
		2 {
			r = c1
			g = value
			b = c3
		}
		3 {
			r = c1
			g = c2
			b = value
		}
		4 {
			r = c3
			g = c1
			b = value
		}
		else {
			r = value
			g = c1
			b = c2
		}
	}
	return Color{
		r: u8(int(math.round(r * 255.0)))
		g: u8(int(math.round(g * 255.0)))
		b: u8(int(math.round(b * 255.0)))
		a: alpha
	}
}

fn light_color_for_inset_and_outset(color Color) Color {
	hue, saturation, value := color_hsv(color)
	if value >= border_dark_light_absolute_value_difference {
		return color
	}
	return color_from_hsv(hue, saturation, value + border_dark_light_absolute_value_difference, color.a)
}

fn dark_color_for_inset_and_outset(color Color) Color {
	hue, saturation, value := color_hsv(color)
	if value < border_dark_light_absolute_value_difference {
		return color
	}
	return color_from_hsv(hue, saturation, value - border_dark_light_absolute_value_difference, color.a)
}

// Direct translation of Painting::border_color(). Inset and outset alter only
// the two opposing edge pairs and retain the source alpha.
pub fn border_color(edge BorderEdge, borders DeviceBordersData) Color {
	border := borders.for_edge(edge)
	if border.line_style == .inset {
		if edge == .left || edge == .top {
			return dark_color_for_inset_and_outset(border.color)
		}
		return light_color_for_inset_and_outset(border.color)
	}
	if border.line_style == .outset {
		if edge == .left || edge == .top {
			return light_color_for_inset_and_outset(border.color)
		}
		return dark_color_for_inset_and_outset(border.color)
	}
	return border.color
}

fn device_borders_with_edge_style(borders DeviceBordersData, edge BorderEdge,
	style LineStyle) DeviceBordersData {
	return DeviceBordersData{
		top: if edge == .top {
			DeviceBorderData{ ...borders.top, line_style: style }
		} else {
			borders.top
		}
		right: if edge == .right {
			DeviceBorderData{ ...borders.right, line_style: style }
		} else {
			borders.right
		}
		bottom: if edge == .bottom {
			DeviceBorderData{ ...borders.bottom, line_style: style }
		} else {
			borders.bottom
		}
		left: if edge == .left {
			DeviceBorderData{ ...borders.left, line_style: style }
		} else {
			borders.left
		}
	}
}

fn proportional_device_border_band(borders DeviceBordersData,
	proportion f64) DeviceBordersData {
	return DeviceBordersData{
		top: DeviceBorderData{ ...borders.top, width: max_int(1, int(f64(borders.top.width) * proportion)) }
		right: DeviceBorderData{ ...borders.right, width: max_int(1, int(f64(borders.right.width) * proportion)) }
		bottom: DeviceBorderData{ ...borders.bottom, width: max_int(1, int(f64(borders.bottom.width) * proportion)) }
		left: DeviceBorderData{ ...borders.left, width: max_int(1, int(f64(borders.left.width) * proportion)) }
	}
}

fn border_path_point(x int, y int) Point {
	return Point{f64(x), f64(y)}
}

fn translated_border_path_point(point Point, x f64, y f64) Point {
	return Point{point.x + x, point.y + y}
}

// BorderPainting.cpp computes the corner split at the point on the ellipse
// whose tangent has slope one. Keeping that rule here is important for unequal
// adjacent widths: an axis-aligned half-radius split produces visibly different
// joins and a different path tessellation cost.
fn border_path_midpoint(edge BorderEdge, horizontal_radius int, vertical_radius int,
	joined_border_width int) Point {
	if horizontal_radius == 0 && vertical_radius == 0 {
		return Point{}
	}
	if joined_border_width == 0 {
		return match edge {
			.top, .bottom { Point{f64(horizontal_radius), 0} }
			.right, .left { Point{0, f64(vertical_radius)} }
		}
	}
	denominator := math.sqrt(f64(horizontal_radius * horizontal_radius + vertical_radius * vertical_radius))
	return Point{
		x: f64(horizontal_radius * horizontal_radius) / denominator
		y: f64(vertical_radius * vertical_radius) / denominator
	}
}

struct BorderPathGeometry {
	points                           []Point
	joined_corner_has_inner_corner   bool
	opposite_corner_has_inner_corner bool
	joined_inner_corner_offset       Size
	opposite_inner_corner_offset     Size
}

fn top_border_path_geometry(rect IntRect, radius CornerRadius, opposite_radius CornerRadius,
	borders DeviceBordersData) BorderPathGeometry {
	tl := border_path_point(rect.left(), rect.top())
	tr := border_path_point(rect.right(), rect.top())
	bl := border_path_point(rect.left(), rect.bottom())
	br := border_path_point(rect.right(), rect.bottom())
	border_width := borders.top.width
	joined_width := borders.left.width
	opposite_width := borders.right.width
	joined_inner := border_width < radius.vertical && joined_width < radius.horizontal
	opposite_inner := border_width < opposite_radius.vertical
		&& opposite_width < opposite_radius.horizontal
	joined_midpoint := border_path_midpoint(.top, radius.horizontal, radius.vertical, joined_width)
	opposite_midpoint := border_path_midpoint(.top, opposite_radius.horizontal, opposite_radius.vertical, opposite_width)
	mut points := [tl,
		translated_border_path_point(tl, -joined_midpoint.x, f64(radius.vertical) - joined_midpoint.y)]
	if joined_inner {
		midpoint := border_path_midpoint(.top, radius.horizontal - joined_width, radius.vertical - border_width, joined_width)
		points << translated_border_path_point(bl, -midpoint.x, f64(radius.vertical - border_width) - midpoint.y)
		points << bl
	} else {
		points << translated_border_path_point(bl, f64(joined_width - radius.horizontal), 0)
	}
	if opposite_inner {
		midpoint := border_path_midpoint(.top, opposite_radius.horizontal - opposite_width, opposite_radius.vertical - border_width, opposite_width)
		points << br
		points << translated_border_path_point(br, midpoint.x, f64(opposite_radius.vertical - border_width) - midpoint.y)
	} else {
		points << translated_border_path_point(br, f64(opposite_radius.horizontal - opposite_width), 0)
	}
	points << translated_border_path_point(tr, opposite_midpoint.x, f64(opposite_radius.vertical) - opposite_midpoint.y)
	points << tr
	return BorderPathGeometry{
		points: points
		joined_corner_has_inner_corner: joined_inner
		opposite_corner_has_inner_corner: opposite_inner
		joined_inner_corner_offset: Size{f64(joined_width), f64(border_width)}
		opposite_inner_corner_offset: Size{f64(opposite_width), f64(border_width)}
	}
}

fn right_border_path_geometry(rect IntRect, radius CornerRadius, opposite_radius CornerRadius,
	borders DeviceBordersData) BorderPathGeometry {
	tl := border_path_point(rect.left(), rect.top())
	tr := border_path_point(rect.right(), rect.top())
	bl := border_path_point(rect.left(), rect.bottom())
	br := border_path_point(rect.right(), rect.bottom())
	border_width := borders.right.width
	joined_width := borders.top.width
	opposite_width := borders.bottom.width
	joined_inner := border_width < radius.horizontal && joined_width < radius.vertical
	opposite_inner := border_width < opposite_radius.horizontal
		&& opposite_width < opposite_radius.vertical
	joined_midpoint := border_path_midpoint(.right, radius.horizontal, radius.vertical, joined_width)
	opposite_midpoint := border_path_midpoint(.right, opposite_radius.horizontal, opposite_radius.vertical, opposite_width)
	mut points := [tr,
		translated_border_path_point(tr, joined_midpoint.x - f64(radius.horizontal), -joined_midpoint.y)]
	if joined_inner {
		midpoint := border_path_midpoint(.right, radius.horizontal - border_width, radius.vertical - joined_width, joined_width)
		points << translated_border_path_point(tl, midpoint.x + f64(border_width - radius.horizontal), -midpoint.y)
		points << tl
	} else {
		points << translated_border_path_point(tl, 0, f64(joined_width - radius.horizontal))
	}
	if opposite_inner {
		midpoint := border_path_midpoint(.right, opposite_radius.horizontal - border_width, opposite_radius.vertical - opposite_width, opposite_width)
		points << bl
		points << translated_border_path_point(bl, midpoint.x + f64(border_width - opposite_radius.horizontal), midpoint.y)
	} else {
		points << translated_border_path_point(bl, 0, f64(opposite_radius.horizontal - opposite_width))
	}
	points << translated_border_path_point(br, opposite_midpoint.x - f64(opposite_radius.horizontal), opposite_midpoint.y)
	points << br
	return BorderPathGeometry{
		points: points
		joined_corner_has_inner_corner: joined_inner
		opposite_corner_has_inner_corner: opposite_inner
		joined_inner_corner_offset: Size{f64(border_width), f64(joined_width)}
		opposite_inner_corner_offset: Size{f64(border_width), f64(opposite_width)}
	}
}

fn bottom_border_path_geometry(rect IntRect, radius CornerRadius, opposite_radius CornerRadius,
	borders DeviceBordersData) BorderPathGeometry {
	tl := border_path_point(rect.left(), rect.top())
	tr := border_path_point(rect.right(), rect.top())
	bl := border_path_point(rect.left(), rect.bottom())
	br := border_path_point(rect.right(), rect.bottom())
	border_width := borders.bottom.width
	joined_width := borders.right.width
	opposite_width := borders.left.width
	joined_inner := border_width < radius.vertical && joined_width < radius.horizontal
	opposite_inner := border_width < opposite_radius.vertical
		&& opposite_width < opposite_radius.horizontal
	joined_midpoint := border_path_midpoint(.bottom, radius.horizontal, radius.vertical, joined_width)
	opposite_midpoint := border_path_midpoint(.bottom, opposite_radius.horizontal, opposite_radius.vertical, opposite_width)
	mut points := [br,
		translated_border_path_point(br, joined_midpoint.x, joined_midpoint.y - f64(radius.vertical))]
	if joined_inner {
		midpoint := border_path_midpoint(.bottom, radius.horizontal - joined_width, radius.vertical - border_width, joined_width)
		points << translated_border_path_point(tr, midpoint.x, midpoint.y + f64(border_width - radius.vertical))
		points << tr
	} else {
		points << translated_border_path_point(tr, f64(radius.horizontal - joined_width), 0)
	}
	if opposite_inner {
		midpoint := border_path_midpoint(.bottom, opposite_radius.horizontal - opposite_width, opposite_radius.vertical - border_width, opposite_width)
		points << tl
		points << translated_border_path_point(tl, -midpoint.x, midpoint.y + f64(border_width - opposite_radius.vertical))
	} else {
		points << translated_border_path_point(tl, f64(opposite_width - opposite_radius.horizontal), 0)
	}
	points << translated_border_path_point(bl, -opposite_midpoint.x, opposite_midpoint.y - f64(opposite_radius.vertical))
	points << bl
	return BorderPathGeometry{
		points: points
		joined_corner_has_inner_corner: joined_inner
		opposite_corner_has_inner_corner: opposite_inner
		joined_inner_corner_offset: Size{f64(joined_width), f64(border_width)}
		opposite_inner_corner_offset: Size{f64(opposite_width), f64(border_width)}
	}
}

fn left_border_path_geometry(rect IntRect, radius CornerRadius, opposite_radius CornerRadius,
	borders DeviceBordersData) BorderPathGeometry {
	tl := border_path_point(rect.left(), rect.top())
	tr := border_path_point(rect.right(), rect.top())
	bl := border_path_point(rect.left(), rect.bottom())
	br := border_path_point(rect.right(), rect.bottom())
	border_width := borders.left.width
	joined_width := borders.bottom.width
	opposite_width := borders.top.width
	joined_inner := border_width < radius.horizontal && joined_width < radius.vertical
	opposite_inner := border_width < opposite_radius.horizontal
		&& opposite_width < opposite_radius.vertical
	joined_midpoint := border_path_midpoint(.left, radius.horizontal, radius.vertical, joined_width)
	opposite_midpoint := border_path_midpoint(.left, opposite_radius.horizontal, opposite_radius.vertical, opposite_width)
	mut points := [bl,
		translated_border_path_point(bl, f64(radius.horizontal) - joined_midpoint.x, joined_midpoint.y)]
	if joined_inner {
		midpoint := border_path_midpoint(.left, radius.horizontal - border_width, radius.vertical - joined_width, joined_width)
		points << translated_border_path_point(br, f64(radius.horizontal - border_width) - midpoint.x, midpoint.y)
		points << br
	} else {
		points << translated_border_path_point(br, 0, f64(radius.vertical - joined_width))
	}
	if opposite_inner {
		midpoint := border_path_midpoint(.left, opposite_radius.horizontal - border_width, opposite_radius.vertical - opposite_width, opposite_width)
		points << tr
		points << translated_border_path_point(tr, f64(opposite_radius.horizontal - border_width) - midpoint.x, -midpoint.y)
	} else {
		points << translated_border_path_point(tr, 0, f64(opposite_width - opposite_radius.vertical))
	}
	points << translated_border_path_point(tl, f64(opposite_radius.horizontal) - opposite_midpoint.x, -opposite_midpoint.y)
	points << tl
	return BorderPathGeometry{
		points: points
		joined_corner_has_inner_corner: joined_inner
		opposite_corner_has_inner_corner: opposite_inner
		joined_inner_corner_offset: Size{f64(border_width), f64(joined_width)}
		opposite_inner_corner_offset: Size{f64(border_width), f64(opposite_width)}
	}
}

fn border_path_geometry(edge BorderEdge, rect IntRect, radius CornerRadius,
	opposite_radius CornerRadius, borders DeviceBordersData) BorderPathGeometry {
	return match edge {
		.top { top_border_path_geometry(rect, radius, opposite_radius, borders) }
		.right { right_border_path_geometry(rect, radius, opposite_radius, borders) }
		.bottom { bottom_border_path_geometry(rect, radius, opposite_radius, borders) }
		.left { left_border_path_geometry(rect, radius, opposite_radius, borders) }
	}
}

fn append_border_path_geometry(mut segments []ClipPathSegment, geometry BorderPathGeometry,
	radius CornerRadius, opposite_radius CornerRadius) {
	mut current := 0
	segments << ClipPathSegment{
		kind: .move_to
		point: geometry.points[current]
	}
	current++
	segments << ClipPathSegment{
		kind: .elliptical_arc_to
		point: geometry.points[current]
		radii: Size{f64(radius.horizontal), f64(radius.vertical)}
	}
	current++
	segments << ClipPathSegment{
		kind: .line_to
		point: geometry.points[current]
	}
	current++
	if geometry.joined_corner_has_inner_corner {
		segments << ClipPathSegment{
			kind: .elliptical_arc_to
			point: geometry.points[current]
			radii: Size{
				width: f64(radius.horizontal) - geometry.joined_inner_corner_offset.width
				height: f64(radius.vertical) - geometry.joined_inner_corner_offset.height
			}
			sweep: true
		}
		current++
	}
	segments << ClipPathSegment{
		kind: .line_to
		point: geometry.points[current]
	}
	current++
	if geometry.opposite_corner_has_inner_corner {
		segments << ClipPathSegment{
			kind: .elliptical_arc_to
			point: geometry.points[current]
			radii: Size{
				width: f64(opposite_radius.horizontal) - geometry.opposite_inner_corner_offset.width
				height: f64(opposite_radius.vertical) - geometry.opposite_inner_corner_offset.height
			}
			sweep: true
		}
		current++
	}
	segments << ClipPathSegment{
		kind: .line_to
		point: geometry.points[current]
	}
	current++
	segments << ClipPathSegment{
		kind: .elliptical_arc_to
		point: geometry.points[current]
		radii: Size{f64(opposite_radius.horizontal), f64(opposite_radius.vertical)}
	}
}

fn flush_border_path(mut commands []DisplayListCommand, mut segments []ClipPathSegment,
	border_rect IntRect, color Color) {
	if segments.len == 0 {
		return
	}
	path := ClipPathVisualData{
		bounding_rect: border_rect
		segments: segments.clone()
		fill_rule: .even_odd
	}
	commands << FillPath{
		path_id: 'border'
		path_bounding_rect: border_rect
		path: path
		color: color
		winding_rule: .even_odd
	}
	segments.clear()
}

fn shrink_border_path_rect(rect IntRect, top int, right int, bottom int,
	left int) IntRect {
	return IntRect{
		x: rect.x + left
		y: rect.y + top
		width: max_int(0, rect.width - left - right)
		height: max_int(0, rect.height - top - bottom)
	}
}

fn append_border_line_command(mut commands []DisplayListCommand, edge BorderEdge, rect IntRect,
	border DeviceBorderData, color Color) {
	half := border.width / 2
	mut from := IntPoint{rect.x, rect.y}
	mut to := IntPoint{rect.right() - 1, rect.y}
	match edge {
		.top {
			from = IntPoint{from.x + half, from.y + half}
			to = IntPoint{to.x - half, to.y + half}
		}
		.right {
			from = IntPoint{rect.right() - 1 - half, rect.y + half}
			to = IntPoint{from.x, rect.bottom() - 1 - half}
		}
		.bottom {
			from = IntPoint{rect.x + half, rect.bottom() - 1 - half}
			to = IntPoint{rect.right() - 1 - half, rect.bottom() - 1 - half}
		}
		.left {
			from = IntPoint{rect.x + half, rect.y + half}
			to = IntPoint{from.x, rect.bottom() - 1 - half}
		}
	}
	commands << DrawLine{
		from: from
		to: to
		color: color
		thickness: border.width
		line_style: border.line_style
	}
}

fn paint_border(mut commands []DisplayListCommand, mut segments []ClipPathSegment,
	edge BorderEdge, rect IntRect, radius CornerRadius, opposite_radius CornerRadius,
	borders DeviceBordersData, border_rect IntRect, last bool) {
	border := borders.for_edge(edge)
	color := border_color(edge, borders)
	next_edge := match edge {
		.top { BorderEdge.right }
		.right { BorderEdge.bottom }
		.bottom { BorderEdge.left }
		.left { BorderEdge.top }
	}
	if border.width <= 0 || border.line_style in [.none, .hidden] {
		// Invisible edges still delimit color runs. Otherwise queued geometry
		// can acquire the next visible edge's color when zero-width sides intervene.
		if segments.len > 0 && (last || color != border_color(next_edge, borders)) {
			flush_border_path(mut commands, mut segments, border_rect, color)
		}
		return
	}
	if border.line_style in [.dotted, .dashed] {
		append_border_line_command(mut commands, edge, rect, border, color)
		return
	}
	mut proportion := 0.0
	mut outer_style := border.line_style
	mut inner_style := border.line_style
	match border.line_style {
		.double {
			proportion = 1.0 / 3.0
			outer_style = .solid
			inner_style = .solid
		}
		.groove {
			proportion = 0.5
			outer_style = .inset
			inner_style = .outset
		}
		.ridge {
			proportion = 0.5
			outer_style = .outset
			inner_style = .inset
		}
		else {
			geometry := border_path_geometry(edge, rect, radius, opposite_radius, borders)
			append_border_path_geometry(mut segments, geometry, radius, opposite_radius)
			if last || color != border_color(next_edge, borders) {
				flush_border_path(mut commands, mut segments, border_rect, color)
			}
			return
		}
	}
	band := proportional_device_border_band(borders, proportion)
	mut modified_rect := match edge {
		.top {
			IntRect{ ...rect, height: max_int(1, int(f64(rect.height) * proportion)) }
		}
		.right {
			width := max_int(1, int(f64(rect.width) * proportion))
			IntRect{ ...rect, x: rect.right() - width, width: width }
		}
		.bottom {
			height := max_int(1, int(f64(rect.height) * proportion))
			IntRect{ ...rect, y: rect.bottom() - height, height: height }
		}
		.left {
			IntRect{ ...rect, width: max_int(1, int(f64(rect.width) * proportion)) }
		}
	}
	paint_border(mut commands, mut segments, edge, modified_rect, radius, opposite_radius, device_borders_with_edge_style(band, edge, outer_style), border_rect, true)
	top_inset := borders.top.width - band.top.width
	right_inset := borders.right.width - band.right.width
	bottom_inset := borders.bottom.width - band.bottom.width
	left_inset := borders.left.width - band.left.width
	mut modified_radius := radius
	mut modified_opposite_radius := opposite_radius
	match edge {
		.top {
			modified_radius.horizontal = max_int(0, modified_radius.horizontal - left_inset)
			modified_opposite_radius.horizontal = max_int(0, modified_opposite_radius.horizontal - right_inset)
			modified_radius.vertical = max_int(0, modified_radius.vertical - top_inset)
			modified_opposite_radius.vertical = modified_radius.vertical
			modified_rect = IntRect{ ...modified_rect, y: rect.bottom() - modified_rect.height }
			if modified_radius.horizontal == 0 && modified_opposite_radius.horizontal == 0 {
				modified_rect = shrink_border_path_rect(modified_rect, 0, right_inset, 0, left_inset)
			}
		}
		.right {
			modified_radius.horizontal = max_int(0, modified_radius.horizontal - right_inset)
			modified_opposite_radius.horizontal = modified_radius.horizontal
			modified_radius.vertical = max_int(0, modified_radius.vertical - top_inset)
			modified_opposite_radius.vertical = max_int(0, modified_opposite_radius.vertical - bottom_inset)
			modified_rect = IntRect{ ...modified_rect, x: rect.x }
			if modified_radius.vertical == 0 && modified_opposite_radius.vertical == 0 {
				modified_rect = shrink_border_path_rect(modified_rect, top_inset, 0, bottom_inset, 0)
			}
		}
		.bottom {
			modified_radius.horizontal = max_int(0, modified_radius.horizontal - right_inset)
			modified_opposite_radius.horizontal = max_int(0, modified_opposite_radius.horizontal - left_inset)
			modified_radius.vertical = max_int(0, modified_radius.vertical - bottom_inset)
			modified_opposite_radius.vertical = modified_radius.vertical
			modified_rect = IntRect{ ...modified_rect, y: rect.y }
			if modified_radius.horizontal == 0 && modified_opposite_radius.horizontal == 0 {
				modified_rect = shrink_border_path_rect(modified_rect, 0, right_inset, 0, left_inset)
			}
		}
		.left {
			modified_radius.horizontal = max_int(0, modified_radius.horizontal - left_inset)
			modified_opposite_radius.horizontal = modified_radius.horizontal
			modified_radius.vertical = max_int(0, modified_radius.vertical - bottom_inset)
			modified_opposite_radius.vertical = max_int(0, modified_opposite_radius.vertical - top_inset)
			modified_rect = IntRect{ ...modified_rect, x: rect.right() - modified_rect.width }
			if modified_radius.vertical == 0 && modified_opposite_radius.vertical == 0 {
				modified_rect = shrink_border_path_rect(modified_rect, top_inset, 0, bottom_inset, 0)
			}
		}
	}
	paint_border(mut commands, mut segments, edge, modified_rect, modified_radius, modified_opposite_radius, device_borders_with_edge_style(band, edge, inner_style), border_rect, true)
}

fn device_border_edge_rect(rect IntRect, edge BorderEdge, radii CornerRadii,
	borders DeviceBordersData) IntRect {
	return match edge {
		.top {
			IntRect{
				x: rect.x + radii.top_left.horizontal
				y: rect.y
				width: rect.width - radii.top_left.horizontal - radii.top_right.horizontal
				height: borders.top.width
			}
		}
		.right {
			IntRect{
				x: rect.right() - borders.right.width
				y: rect.y + radii.top_right.vertical
				width: borders.right.width
				height: rect.height - radii.top_right.vertical - radii.bottom_right.vertical
			}
		}
		.bottom {
			IntRect{
				x: rect.x + radii.bottom_left.horizontal
				y: rect.bottom() - borders.bottom.width
				width: rect.width - radii.bottom_left.horizontal - radii.bottom_right.horizontal
				height: borders.bottom.width
			}
		}
		.left {
			IntRect{
				x: rect.x
				y: rect.y + radii.top_left.vertical
				width: borders.left.width
				height: rect.height - radii.top_left.vertical - radii.bottom_left.vertical
			}
		}
	}
}

fn border_edge_radii(edge BorderEdge, radii CornerRadii) (CornerRadius, CornerRadius) {
	return match edge {
		.top { radii.top_left, radii.top_right }
		.right { radii.top_right, radii.bottom_right }
		.bottom { radii.bottom_right, radii.bottom_left }
		.left { radii.bottom_left, radii.top_left }
	}
}

// Direct translation of Painting::paint_all_borders(). Solid edges retain the
// exact joined elliptical path; adjacent same-colored edges are batched into
// one FillPath, while dotted/dashed and double/groove/ridge recurse through the
// same edge dispatcher as C++.
pub fn paint_all_borders(rect IntRect, radii CornerRadii,
	borders DeviceBordersData) []DisplayListCommand {
	if borders.top.width <= 0 && borders.right.width <= 0 && borders.bottom.width <= 0
		&& borders.left.width <= 0 {
		return []
	}
	mut used_radii := radii
	if borders.bottom.width <= 0 && borders.left.width <= 0 {
		used_radii.bottom_left = CornerRadius{}
	}
	if borders.bottom.width <= 0 && borders.right.width <= 0 {
		used_radii.bottom_right = CornerRadius{}
	}
	if borders.top.width <= 0 && borders.left.width <= 0 {
		used_radii.top_left = CornerRadius{}
	}
	if borders.top.width <= 0 && borders.right.width <= 0 {
		used_radii.top_right = CornerRadius{}
	}
	mut edges := [BorderEdge.top, .right, .bottom, .left]
	for _ in 0 .. edges.len {
		first := edges[0]
		second := edges[1]
		edges = edges[1..].clone()
		edges << first
		if border_color(first, borders) != border_color(second, borders) {
			break
		}
	}
	mut commands := []DisplayListCommand{}
	mut segments := []ClipPathSegment{}
	for index, edge in edges {
		radius, opposite_radius := border_edge_radii(edge, used_radii)
		paint_border(mut commands, mut segments, edge, device_border_edge_rect(rect, edge, used_radii, borders), radius, opposite_radius, borders, rect, index == edges.len - 1)
	}
	return commands
}

// Translation of Painting::borders_data_for_outline() after CSS has resolved
// `outline-style:auto` to its accent color, solid style, and 2px width.
pub fn borders_data_for_outline(outline_color Color, line_style LineStyle,
	outline_width f64) ?BordersData {
	if outline_color.a == 0 || line_style == .none || outline_width == 0 {
		return none
	}
	border := BorderData{
		color: outline_color
		line_style: line_style
		width: outline_width
	}
	return BordersData{
		top: border
		right: border
		bottom: border
		left: border
	}
}

pub enum ConflictingElementKind {
	cell
	row
	row_group
	column
	column_group
	table
}

pub struct ConflictingBorder {
pub:
	border       DeviceBorderData
	element_kind ConflictingElementKind
	tree_order   int
}

fn style_precedence(style LineStyle) int {
	return match style {
		.hidden { 10 }
		.double { 9 }
		.solid { 8 }
		.dashed { 7 }
		.dotted { 6 }
		.ridge { 5 }
		.outset { 4 }
		.groove { 3 }
		.inset { 2 }
		.none { 1 }
	}
}

fn element_precedence(kind ConflictingElementKind) int {
	return match kind {
		.cell { 6 }
		.row { 5 }
		.row_group { 4 }
		.column { 3 }
		.column_group { 2 }
		.table { 1 }
	}
}

pub fn resolve_table_border_conflict(first ConflictingBorder,
	second ConflictingBorder) ConflictingBorder {
	if first.border.line_style == .hidden {
		return first
	}
	if second.border.line_style == .hidden {
		return second
	}
	if first.border.line_style == .none {
		return second
	}
	if second.border.line_style == .none {
		return first
	}
	if first.border.width != second.border.width {
		return if first.border.width > second.border.width { first } else { second }
	}
	first_style := style_precedence(first.border.line_style)
	second_style := style_precedence(second.border.line_style)
	if first_style != second_style {
		return if first_style > second_style { first } else { second }
	}
	first_element := element_precedence(first.element_kind)
	second_element := element_precedence(second.element_kind)
	if first_element != second_element {
		return if first_element > second_element { first } else { second }
	}
	// For otherwise identical borders, CSS 2.2 gives the edge further left/top
	// precedence. tree_order stores that monotonically increasing position.
	return if first.tree_order <= second.tree_order { first } else { second }
}

pub fn fieldset_effective_border_top(border_top f64, legend_margin_height f64,
	legend_border_height f64, has_rendered_legend bool) f64 {
	if !has_rendered_legend {
		return border_top
	}
	return math.max(border_top, legend_margin_height + legend_border_height)
}

pub struct FieldSetPaintable {
pub:
	border_rect              Rect
	css_border_top           f64
	legend_margin_box_height f64
	legend_border_rect       ?Rect
}

pub struct FieldSetPaintCommand {
pub:
	command DisplayListCommand
	clip    ?IntRect
}

// Direct translation of FieldSetPaintable::effective_border_top().
pub fn (fieldset FieldSetPaintable) effective_border_top() f64 {
	return fieldset_effective_border_top(fieldset.css_border_top, fieldset.legend_margin_box_height, 0, fieldset.legend_border_rect != none)
}

// Direct translation of FieldSetPaintable::visual_border_box_rect().
pub fn (fieldset FieldSetPaintable) visual_border_box_rect() Rect {
	allocated_border_top := fieldset.effective_border_top()
	if allocated_border_top <= fieldset.css_border_top {
		return fieldset.border_rect
	}
	removed_height := math.min((allocated_border_top - fieldset.css_border_top) / 2.0, fieldset.border_rect.height)
	return Rect{
		...fieldset.border_rect
		y: fieldset.border_rect.y + removed_height
		height: fieldset.border_rect.height - removed_height
	}
}

// FieldSetPaintable::paint_background() clips only the resolved background;
// shadows, borders, descendants, and outlines remain outside this clip.
pub fn (fieldset FieldSetPaintable) background_clip_rect(converter DevicePixelConverter) ?IntRect {
	return converter.rounded_device_rect(fieldset.visual_border_box_rect())
}

fn append_fieldset_paint_commands(mut result []FieldSetPaintCommand,
	commands []DisplayListCommand, clip ?IntRect) {
	for command in commands {
		result << FieldSetPaintCommand{
			command: command
			clip: clip
		}
	}
}

// Direct translation of FieldSetPaintable::paint()'s border phase. The side
// and bottom borders use the shifted visual box, while the top border is
// replayed through the two clips on either side of the rendered legend.
pub fn (fieldset FieldSetPaintable) paint(borders DeviceBordersData, radii CornerRadii,
	converter DevicePixelConverter) []FieldSetPaintCommand {
	legend_border_rect := fieldset.legend_border_rect or {
		return paint_all_borders(converter.rounded_device_rect(fieldset.border_rect), radii, borders).map(FieldSetPaintCommand{
			command: it
		})
	}
	device_border_rect := converter.rounded_device_rect(fieldset.visual_border_box_rect())
	mut result := []FieldSetPaintCommand{}
	append_fieldset_paint_commands(mut result, paint_all_borders(device_border_rect, radii, DeviceBordersData{
		top: DeviceBorderData{}
		right: borders.right
		bottom: borders.bottom
		left: borders.left
	}), none)
	top_border_only := DeviceBordersData{
		top: borders.top
	}
	legend_device_rect := converter.rounded_device_rect(legend_border_rect)
	left_segment := IntRect{
		x: device_border_rect.x
		y: device_border_rect.y
		width: legend_device_rect.x - device_border_rect.x
		height: borders.top.width
	}
	right_segment := IntRect{
		x: legend_device_rect.right()
		y: device_border_rect.y
		width: device_border_rect.right() - legend_device_rect.right()
		height: borders.top.width
	}
	// The native transport cannot express the Rust recorder's intersect-plus-
	// difference inline clip stack. For the overwhelmingly common square solid
	// edge, record the two visible runs directly; this is pixel-identical to
	// clipping the complete top border and avoids replaying two identical path
	// commands through independently allocated clip lists.
	if borders.top.line_style == .solid && radii == CornerRadii{} {
		for segment in [left_segment, right_segment] {
			if segment.width > 0 && segment.height > 0 {
				result << FieldSetPaintCommand{
					command: FillRect{
						rect: segment
						color: borders.top.color
					}
				}
			}
		}
		return result
	}
	top_commands := paint_all_borders(device_border_rect, radii, top_border_only)
	append_fieldset_paint_commands(mut result, top_commands, left_segment)
	append_fieldset_paint_commands(mut result, top_commands, right_segment)
	return result
}

pub enum MarkerKind {
	square
	circle
	disc
	disclosure_closed
	disclosure_open
}

pub struct MarkerPaintable {
pub:
	marker_rect Rect
	kind        MarkerKind
	color       Color
}

pub fn marker_kind_from_name(name string) ?MarkerKind {
	return match name {
		'square' { .square }
		'circle' { .circle }
		'disc' { .disc }
		'disclosure-closed' { .disclosure_closed }
		'disclosure-open' { .disclosure_open }
		else { none }
	}
}

fn marker_triangle_path(kind MarkerKind, rect IntRect) ClipPathVisualData {
	left := f64(rect.x)
	right := left + f64(rect.width)
	top := f64(rect.y)
	bottom := top + f64(rect.height)
	points := if kind == .disclosure_closed {
		[Point{left, top}, Point{left + 0.866025403 * (right - left), (top + bottom) / 2.0},
			Point{left, bottom}]
	} else {
		[Point{left, top}, Point{right, top},
			Point{(left + right) / 2.0, top + 0.866025403 * (bottom - top)}]
	}
	return ClipPathVisualData{
		bounding_rect: rect
		segments: [
			ClipPathSegment{
				kind: .move_to
				point: points[0]
			},
			ClipPathSegment{
				kind: .line_to
				point: points[1]
			},
			ClipPathSegment{
				kind: .line_to
				point: points[2]
			},
			ClipPathSegment{ kind: .close_path },
		]
		polygons: [points.clone()]
		polygon: points
		fill_rule: .even_odd
	}
}

pub fn marker_command(kind MarkerKind, rect IntRect, color Color) DisplayListCommand {
	return match kind {
		.square {
			FillRect{rect, color}
		}
		.circle {
			DrawEllipse{rect, color, 1}
		}
		.disc {
			FillEllipse{rect, color}
		}
		.disclosure_closed {
			FillPath{
				path_id: 'triangle-right'
				path_bounding_rect: rect
				path: marker_triangle_path(kind, rect)
				color: color
				winding_rule: .even_odd
			}
		}
		.disclosure_open {
			FillPath{
				path_id: 'triangle-down'
				path_bounding_rect: rect
				path: marker_triangle_path(kind, rect)
				color: color
				winding_rule: .even_odd
			}
		}
	}
}

// Direct translation of MarkerPaintable::paint()'s geometric-marker branch.
pub fn (marker MarkerPaintable) paint(converter DevicePixelConverter) []DisplayListCommand {
	rounded_marker_rect := Rect{
		x: math.round(marker.marker_rect.x)
		y: math.round(marker.marker_rect.y)
		width: math.round(marker.marker_rect.width)
		height: math.round(marker.marker_rect.height)
	}
	device_rect := converter.enclosing_device_rect(rounded_marker_rect)
	return [marker_command(marker.kind, device_rect, marker.color)]
}

pub struct InputColors {
pub:
	accent     Color
	base       Color
	dark_gray  Color
	gray       Color
	mid_gray   Color
	light_gray Color
}

pub fn (colors InputColors) background_color(enabled bool) Color {
	return if enabled { colors.base } else { colors.light_gray }
}

pub fn (colors InputColors) border_color(enabled bool) Color {
	return if enabled { colors.gray } else { colors.mid_gray }
}

fn input_color_from_css(color css.Color) Color {
	return Color{color.r, color.g, color.b, color.a}
}

fn mix_input_color(from Color, to Color, weight f64) Color {
	mix_channel := fn [weight] (first f64, second f64) u8 {
		// LibGfx::Color::mixed_with performs its interpolation in f32 and uses
		// Rust's round_ties_even conversion. Preserve both details at the V
		// boundary; ordinary round() biases every exact x.5 shade upward.
		value := f32(first) + (f32(second) - f32(first)) * f32(weight)
		return u8(math.round_to_even(f64(value)))
	}
	if from.a == to.a || (from.r == to.r && from.g == to.g && from.b == to.b) {
		return Color{
			r: mix_channel(from.r, to.r)
			g: mix_channel(from.g, to.g)
			b: mix_channel(from.b, to.b)
			a: mix_channel(from.a, to.a)
		}
	}
	mixed_alpha := f32(from.a) + (f32(to.a) - f32(from.a)) * f32(weight)
	if mixed_alpha == 0 {
		return Color{ a: 0 }
	}
	premultiplied_channel := fn [from, to, weight, mixed_alpha] (first f64, second f64) u8 {
		alpha := f32(from.a)
		other_alpha := f32(to.a)
		a := f32(first) * alpha
		b := f32(second) * other_alpha
		value := (a + (b - a) * f32(weight)) / mixed_alpha
		return u8(math.round_to_even(f64(value)))
	}
	return Color{
		r: premultiplied_channel(from.r, to.r)
		g: premultiplied_channel(from.g, to.g)
		b: premultiplied_channel(from.b, to.b)
		a: u8(math.round_to_even(f64(mixed_alpha)))
	}
}

// Direct translation of Painting::InputColors::get_shade().
fn get_shade(color Color, amount f64, color_scheme css.PreferredColorScheme) Color {
	return mix_input_color(color, input_color_from_css(css.SystemColor.canvas(color_scheme)), amount)
}

fn input_color_inverted(color Color) Color {
	return Color{255 - color.r, 255 - color.g, 255 - color.b, color.a}
}

fn input_color_relative_luminance(color Color) f64 {
	linear_channel := fn (channel u8) f64 {
		value := f64(channel) / 255.0
		return if value <= 0.04045 {
			value / 12.92
		} else {
			math.pow((value + 0.055) / 1.055, 2.4)
		}
	}
	return linear_channel(color.r) * 0.2126 + linear_channel(color.g) * 0.7152 + linear_channel(color.b) * 0.0722
}

fn input_color_contrast_ratio(first Color, second Color) f64 {
	first_luminosity := input_color_relative_luminance(first)
	second_luminosity := input_color_relative_luminance(second)
	darkest := math.min(first_luminosity, second_luminosity)
	brightest := math.max(first_luminosity, second_luminosity)
	return (brightest + 0.05) / (darkest + 0.05)
}

fn increase_input_color_contrast(color Color, background Color) Color {
	if input_color_contrast_ratio(color, background) < 2 {
		inverted := input_color_inverted(color)
		if input_color_contrast_ratio(inverted, background) > 2 {
			return inverted
		}
	}
	return color
}

// Direct translation of Painting/InputColors.h::compute_input_colors().
pub fn compute_input_colors(color_scheme css.PreferredColorScheme, accent_color ?css.Color) InputColors {
	base_text_color := input_color_from_css(css.SystemColor.canvas_text(color_scheme))
	accent := input_color_from_css(accent_color or { css.SystemColor.accent_color(color_scheme) })
	base := get_shade(input_color_inverted(base_text_color), 0.8, color_scheme)
	dark_gray := get_shade(base_text_color, 0.3, color_scheme)
	gray := get_shade(dark_gray, 0.4, color_scheme)
	mid_gray := get_shade(gray, 0.3, color_scheme)
	light_gray := get_shade(mid_gray, 0.3, color_scheme)
	return InputColors{
		accent: accent
		base: base
		dark_gray: dark_gray
		gray: gray
		mid_gray: mid_gray
		light_gray: light_gray
	}
}

// Direct translation of CheckBoxPaintable.cpp::check_mark_path().
fn check_mark_path(rect IntRect) ClipPathVisualData {
	// The upstream Gfx path and transform are f32. Keep the multiply/add order at
	// that precision so Skia sees the same edge coordinates for small controls.
	scale_x := f32(rect.width) / f32(100.0)
	scale_y := f32(rect.height) / f32(100.0)
	points := [
		Point{f64(f32(rect.x) + f32(72.0) * scale_x), f64(f32(rect.y) + f32(14.0) * scale_y)},
		Point{f64(f32(rect.x) + f32(37.0) * scale_x), f64(f32(rect.y) + f32(64.0) * scale_y)},
		Point{f64(f32(rect.x) + f32(19.0) * scale_x), f64(f32(rect.y) + f32(47.0) * scale_y)},
		Point{f64(f32(rect.x) + f32(8.0) * scale_x), f64(f32(rect.y) + f32(58.0) * scale_y)},
		Point{f64(f32(rect.x) + f32(40.0) * scale_x), f64(f32(rect.y) + f32(89.0) * scale_y)},
		Point{f64(f32(rect.x) + f32(85.0) * scale_x), f64(f32(rect.y) + f32(24.0) * scale_y)},
	]
	mut segments := [ClipPathSegment{
		kind: .move_to
		point: points[0]
	}]
	for point in points[1..] {
		segments << ClipPathSegment{
			kind: .line_to
			point: point
		}
	}
	segments << ClipPathSegment{ kind: .close_path }
	return ClipPathVisualData{
		segments: segments
		polygons: [points.clone()]
		polygon: points
	}
}

fn int_rect_inflated_by_total(rect IntRect, width int, height int) IntRect {
	return IntRect{
		x: rect.x - width / 2
		y: rect.y - height / 2
		width: rect.width + width
		height: rect.height + height
	}
}

// CheckBoxPaintable and RadioButtonPaintable paint a centered square inside
// the element's box. Center before converting to device pixels so fractional
// CSS geometry is enclosed as a single rectangle, matching the recorder.
pub fn centered_form_control_rect(outer_rect Rect, converter DevicePixelConverter) IntRect {
	size := math.min(outer_rect.width, outer_rect.height)
	return converter.enclosing_device_rect(Rect{
		x: outer_rect.x + (outer_rect.width - size) / 2.0
		y: outer_rect.y + (outer_rect.height - size) / 2.0
		width: size
		height: size
	})
}

// Direct translation of CheckBoxPaintable::paint()'s foreground phase.
pub fn checkbox_commands(rect IntRect, checked bool, indeterminate bool, enabled bool,
	activated bool, color_scheme css.PreferredColorScheme, colors InputColors) []DisplayListCommand {
	radius := rect.width / 5
	mut commands := []DisplayListCommand{}
	if checked && !indeterminate {
		background := if enabled { colors.accent } else { colors.mid_gray }
		fill := if activated && enabled {
			get_shade(background, 0.3, color_scheme)
		} else {
			background
		}
		commands << FillRoundedRect{rect, fill, uniform_corner_radii(radius)}
		mut tick_color := increase_input_color_contrast(colors.base, background)
		if !enabled {
			tick_color = get_shade(tick_color, 0.5, color_scheme)
		}
		commands << FillPath{
			path_id: 'checkbox-checkmark'
			path_bounding_rect: rect
			path: check_mark_path(rect)
			color: tick_color
			winding_rule: .even_odd
		}
		return commands
	}
	background := colors.background_color(enabled)
	border_thickness := max_int(1, rect.width / 10)
	border := colors.border_color(enabled)
	border_fill := if activated && enabled {
		get_shade(border, 0.3, color_scheme)
	} else {
		border
	}
	commands << FillRoundedRect{rect, border_fill, uniform_corner_radii(radius)}
	inner := rect.inflated(-border_thickness, -border_thickness, -border_thickness, -border_thickness)
	commands << FillRoundedRect{inner, background, uniform_corner_radii(max_int(0, radius - border_thickness))}
	if indeterminate {
		dash := int_rect_inflated_by_total(rect, int(-0.4 * f64(rect.width)), int(-0.8 * f64(rect.height)))
		dash_color := increase_input_color_contrast(colors.dark_gray, background)
		commands << FillRoundedRect{dash, dash_color, uniform_corner_radii(int(0.05 * f64(rect.width)))}
	}
	return commands
}

// Direct translation of RadioButtonPaintable::paint()'s foreground phase.
pub fn radio_button_commands(rect IntRect, checked bool, enabled bool,
	activated bool, color_scheme css.PreferredColorScheme, colors InputColors) []DisplayListCommand {
	outer := max_int(1, int(math.ceil(f64(rect.width) / 13.0)))
	inner := max_int(2, int(math.ceil(f64(rect.width) / 4.0)))
	mut background := colors.background_color(enabled)
	radio_color := if checked { colors.accent } else { colors.gray }
	if checked && enabled && input_color_contrast_ratio(colors.accent, background) < 2
		&& input_color_contrast_ratio(colors.accent, colors.dark_gray) > 2 {
		background = colors.dark_gray
	}
	fill := if !enabled {
		colors.mid_gray
	} else if activated {
		get_shade(radio_color, 0.3, color_scheme)
	} else {
		radio_color
	}
	mut commands := [
		DisplayListCommand(FillRoundedRect{rect, fill, uniform_corner_radii(rect.width / 2)}),
	]
	middle_rect := rect.inflated(-outer, -outer, -outer, -outer)
	commands << FillRoundedRect{middle_rect, background, uniform_corner_radii(middle_rect.width / 2)}
	if checked {
		inner_rect := rect.inflated(-inner, -inner, -inner, -inner)
		commands << FillRoundedRect{inner_rect, fill, uniform_corner_radii(inner_rect.width / 2)}
	}
	return commands
}

pub fn uniform_corner_radii(radius int) CornerRadii {
	corner := CornerRadius{radius, radius}
	return CornerRadii{corner, corner, corner, corner}
}
