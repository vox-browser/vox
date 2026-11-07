module main

import css
import painting
import math

// Keep these bits aligned with VoxGraphiteImage in native_graphite_bridge.h.
const chromium_bitmap_repeat_x = 64
const chromium_bitmap_repeat_y = 128

fn chromium_background_bitmap_pattern_flags(plan painting.BackgroundTilePlan,
	clip painting.Rect) int {
	if !plan.can_use_repeated_bitmap() { return 0 }
	tile := pixel_snapped_background_bitmap_rect(plan.first_tile)
	if tile.x <= clip.x && tile.y <= clip.y && tile.right() >= clip.right()
		&& tile.bottom() >= clip.bottom() {
		// Blink's single-tile optimization crops the source and clamps to that
		// crop, even when the CSS repetition mode is repeat.
		return 0
	}
	mut flags := 0
	// A draw crossing a tile boundary must retain repeat filtering.
	if plan.repeat_x {
		flags |= chromium_bitmap_repeat_x
	}
	if plan.repeat_y {
		flags |= chromium_bitmap_repeat_y
	}
	return flags
}

fn pixel_snapped_background_bitmap_rect(rect painting.Rect) painting.Rect {
	// Chromium rounds halfway values toward positive infinity. An offscreen
	// sprite origin at -1585.5 must not round away from zero: that stretches a
	// 1751px tile to 1752px and filters an otherwise unscaled sprite.
	left := math.floor(rect.x + 0.5)
	top := math.floor(rect.y + 0.5)
	return painting.Rect{left, top, math.floor(rect.right() + 0.5) - left, math.floor(rect.bottom() + 0.5) - top}
}

fn chromium_background_bitmap_plan(plan painting.BackgroundTilePlan, clip painting.Rect) painting.BackgroundTilePlan {
	if !plan.can_use_repeated_bitmap() { return plan }
	mut x := plan.first_tile.x
	mut y := plan.first_tile.y
	if plan.repeat_x && plan.x_step > 0 {
		x += math.floor((clip.x - x) / plan.x_step) * plan.x_step
	}
	if plan.repeat_y && plan.y_step > 0 {
		y += math.floor((clip.y - y) / plan.y_step) * plan.y_step
	}
	return painting.BackgroundTilePlan{
		...plan
		first_tile: painting.Rect{x, y, plan.first_tile.width, plan.first_tile.height}
	}
}

fn chromium_background_bitmap_tiles_are_bounded(plan painting.BackgroundTilePlan,
	clip painting.Rect, maximum int) bool {
	x_count := if plan.repeat_x && plan.x_step > 0 {
		math.max(1.0, math.ceil((clip.right() - plan.first_tile.x) / plan.x_step))
	} else {
		1.0
	}
	y_count := if plan.repeat_y && plan.y_step > 0 {
		math.max(1.0, math.ceil((clip.bottom() - plan.first_tile.y) / plan.y_step))
	} else {
		1.0
	}
	return x_count * y_count <= f64(maximum)
}

// Blink paints a bitmap background with one drawImageRect when a single tile
// covers its destination (BoxPainterBase OptimizeToSingleTileDraw). The
// destination is pixel-snapped, but the source subset comes from the
// unsnapped LayoutUnit tile: snapping the tile first shifts and rescales the
// sampled source, which changes bilinear filtering across an upscaled image.
struct ChromiumSingleTileBackground {
	destination painting.Rect
	source      painting.Rect
	unclamped_source bool
}

struct ChromiumBackgroundAxis {
	paint_position    i64 // LayoutUnit raw values (1/64 CSS pixel)
	paint_size        i64
	area_position     i64
	area_size         i64
	snapped_area_size i64
	tile_size         i64
	position          css.LengthPercentage
	repeats           bool
}

struct ChromiumBackgroundAxisGeometry {
	unsnapped_position i64
	unsnapped_size     i64
	snapped_position   i64
	snapped_size       i64
	phase              i64
}

const chromium_layout_unit = i64(64)

fn chromium_layout_unit_raw(value f64) i64 {
	return i64(math.round(value * f64(chromium_layout_unit)))
}

// LayoutUnit(float) truncates toward zero.
fn chromium_layout_unit_from_float(value f32) i64 {
	return i64(value * f32(chromium_layout_unit))
}

fn chromium_layout_unit_to_float(raw i64) f32 {
	return f32(raw) / f32(chromium_layout_unit)
}

fn chromium_layout_unit_round(raw i64) i64 {
	return ((raw + chromium_layout_unit / 2) >> 6) << 6
}

fn chromium_layout_unit_mul_div(value i64, m i64, d i64) i64 {
	return value * m / d
}

// SnapSizeToPixel rounds the size together with the location's signed
// fraction. LayoutUnit::Round() is floor(value + 0.5).
fn chromium_snap_size_to_pixel(size i64, location i64) i64 {
	fraction := location % chromium_layout_unit
	result := chromium_layout_unit_round(fraction + size) - chromium_layout_unit_round(fraction)
	if result == 0 && (size > 4 || size < -4) {
		return if size > 0 { chromium_layout_unit } else { -chromium_layout_unit }
	}
	return result
}

// MinimumValueForLength: percentages multiply in float, then truncate.
fn chromium_minimum_value_for_length(length css.LengthPercentage, maximum i64,
	context css.LengthResolutionContext) i64 {
	if length.is_percentage() {
		return chromium_layout_unit_from_float(chromium_layout_unit_to_float(maximum) *
			f32(length.percentage().value()) / f32(100))
	}
	return i64(length.to_px(context, css.CSSPixels.from_raw(int(maximum))).raw_value())
}

fn chromium_length_or_auto(length css.LengthPercentageOrAuto, maximum i64,
	context css.LengthResolutionContext) ?i64 {
	if length.is_auto() { return none }
	return chromium_minimum_value_for_length(length.length_percentage(), maximum, context)
}

// BackgroundImageGeometry::CalculateFillTileSize for an image with natural
// dimensions. Cover and contain fit the snapped positioning area.
fn chromium_background_tile_size(layer css.BackgroundLayerData, context css.LengthResolutionContext,
	area_width i64, area_height i64, snapped_width i64, snapped_height i64,
	natural_width f64, natural_height f64) ?(i64, i64) {
	ratio_width := i64(math.floor(f64(f32(natural_width)) * f64(chromium_layout_unit)))
	ratio_height := i64(math.floor(f64(f32(natural_height)) * f64(chromium_layout_unit)))
	if ratio_width <= 0 || ratio_height <= 0 { return none }
	match layer.size_type {
		.cover, .contain {
			grow := layer.size_type == .cover
			mut width := snapped_width
			mut height := chromium_layout_unit_mul_div(snapped_width, ratio_height, ratio_width)
			if (grow && height < snapped_height) || (!grow && height > snapped_height) {
				width = chromium_layout_unit_mul_div(snapped_height, ratio_width, ratio_height)
				height = snapped_height
			}
			if grow {
				if width != snapped_width { width = math.max(chromium_layout_unit, width) }
				if height != snapped_height { height = math.max(chromium_layout_unit, height) }
			} else {
				if width != snapped_width {
					width = math.max(chromium_layout_unit, chromium_layout_unit_round(width))
				}
				if height != snapped_height {
					height = math.max(chromium_layout_unit, chromium_layout_unit_round(height))
				}
			}
			return width, height
		}
		.length_percentage {
			specified_width := chromium_length_or_auto(layer.size_x, area_width, context)
			specified_height := chromium_length_or_auto(layer.size_y, area_height, context)
			mut width := area_width
			mut height := area_height
			if w := specified_width { width = w }
			if h := specified_height { height = h }
			if specified_width == none && specified_height != none {
				width = chromium_layout_unit_mul_div(height, ratio_width, ratio_height)
				if width < chromium_layout_unit { width = chromium_layout_unit }
			} else if specified_width != none && specified_height == none {
				height = chromium_layout_unit_mul_div(width, ratio_height, ratio_width)
				if height < chromium_layout_unit { height = chromium_layout_unit }
			} else if specified_width == none && specified_height == none {
				width = ratio_width
				height = ratio_height
			}
			return math.max(i64(0), width), math.max(i64(0), height)
		}
	}
}

// CalculateRepeatAndPosition for repeat and no-repeat; the box offsets are
// zero when the positioning and painting areas share an origin.
fn chromium_background_axis(axis ChromiumBackgroundAxis, context css.LengthResolutionContext) ChromiumBackgroundAxisGeometry {
	snapped_paint_position := chromium_layout_unit_round(axis.paint_position)
	snapped_paint_size := chromium_snap_size_to_pixel(axis.paint_size, axis.paint_position)
	unsnapped_box_offset := axis.area_position - axis.paint_position
	snapped_box_offset := chromium_layout_unit_round(axis.area_position) - snapped_paint_position
	mut geometry := ChromiumBackgroundAxisGeometry{
		unsnapped_position: axis.paint_position
		unsnapped_size: axis.paint_size
		snapped_position: snapped_paint_position
		snapped_size: snapped_paint_size
	}
	if axis.repeats {
		offset := unsnapped_box_offset + chromium_minimum_value_for_length(axis.position,
			axis.area_size - axis.tile_size, context)
		geometry = ChromiumBackgroundAxisGeometry{
			...geometry
			phase: if axis.tile_size != 0 { axis.tile_size - offset % axis.tile_size } else { 0 }
		}
		return geometry
	}
	offset := unsnapped_box_offset + chromium_minimum_value_for_length(axis.position,
		axis.area_size - axis.tile_size, context)
	snapped_offset := snapped_box_offset + chromium_minimum_value_for_length(axis.position,
		axis.snapped_area_size - axis.tile_size, context)
	if offset > 0 {
		position := geometry.unsnapped_position + offset
		return ChromiumBackgroundAxisGeometry{
			unsnapped_position: position
			unsnapped_size: axis.tile_size
			snapped_position: chromium_layout_unit_round(position)
			snapped_size: axis.tile_size
			phase: 0
		}
	}
	return ChromiumBackgroundAxisGeometry{
		...geometry
		unsnapped_size: axis.tile_size + offset
		snapped_size: axis.tile_size + snapped_offset
		phase: -offset
	}
}

fn chromium_intersect_axis(position i64, size i64, clip_position i64, clip_size i64) (i64, i64) {
	start := math.max(position, clip_position)
	end := math.min(position + size, clip_position + clip_size)
	if end <= start { return start, i64(0) }
	return start, end - start
}

// SnapSourceRectIfNearIntegral rounds a subset whose edges are all within one
// LayoutUnit epsilon of integers.
fn chromium_snap_source_rect(source painting.Rect) painting.Rect {
	epsilon := 1.0 / f64(chromium_layout_unit)
	for value in [source.x, source.y, source.right(), source.bottom()] {
		if math.abs(math.round(value) - value) > epsilon { return source }
	}
	x := math.round(source.x)
	y := math.round(source.y)
	width := math.round(source.right()) - x
	height := math.round(source.bottom()) - y
	if width <= 0 || height <= 0 { return source }
	return painting.Rect{x, y, width, height}
}

fn chromium_single_tile_background(layer css.BackgroundLayerData, context css.LengthResolutionContext,
	paint_rect painting.Rect, area painting.Rect, natural_width f64, natural_height f64) ?ChromiumSingleTileBackground {
	if layer.repeat_x in [.round, .space] || layer.repeat_y in [.round, .space]
		|| layer.attachment != .scroll || natural_width <= 0 || natural_height <= 0 {
		return none
	}
	area_x := chromium_layout_unit_raw(area.x)
	area_y := chromium_layout_unit_raw(area.y)
	area_width := chromium_layout_unit_raw(area.width)
	area_height := chromium_layout_unit_raw(area.height)
	snapped_area_width := chromium_snap_size_to_pixel(area_width, area_x)
	snapped_area_height := chromium_snap_size_to_pixel(area_height, area_y)
	tile_width, tile_height := chromium_background_tile_size(layer, context, area_width,
		area_height, snapped_area_width, snapped_area_height, natural_width, natural_height)?
	if tile_width <= 0 || tile_height <= 0 { return none }
	paint_x := chromium_layout_unit_raw(paint_rect.x)
	paint_y := chromium_layout_unit_raw(paint_rect.y)
	paint_width := chromium_layout_unit_raw(paint_rect.width)
	paint_height := chromium_layout_unit_raw(paint_rect.height)
	x := chromium_background_axis(ChromiumBackgroundAxis{paint_x, paint_width, area_x, area_width,
		snapped_area_width, tile_width, layer.position_x, layer.repeat_x == .repeat}, context)
	y := chromium_background_axis(ChromiumBackgroundAxis{paint_y, paint_height, area_y, area_height,
		snapped_area_height, tile_height, layer.position_y, layer.repeat_y == .repeat}, context)
	// Clip both destinations to the unsnapped paint rect, then re-snap.
	unsnapped_x, unsnapped_width := chromium_intersect_axis(x.unsnapped_position, x.unsnapped_size, paint_x, paint_width)
	unsnapped_y, unsnapped_height := chromium_intersect_axis(y.unsnapped_position, y.unsnapped_size, paint_y, paint_height)
	clipped_x, clipped_width := chromium_intersect_axis(x.snapped_position, x.snapped_size, paint_x, paint_width)
	clipped_y, clipped_height := chromium_intersect_axis(y.snapped_position, y.snapped_size, paint_y, paint_height)
	if unsnapped_width <= 0 || unsnapped_height <= 0 || clipped_width <= 0 || clipped_height <= 0 {
		return none
	}
	_ = unsnapped_x
	_ = unsnapped_y
	dest_x := chromium_layout_unit_round(clipped_x)
	dest_y := chromium_layout_unit_round(clipped_y)
	dest_width := chromium_snap_size_to_pixel(clipped_width, clipped_x)
	dest_height := chromium_snap_size_to_pixel(clipped_height, clipped_y)
	if dest_width <= 0 || dest_height <= 0 { return none }
	// ComputePhase: IntMod keeps the dividend's sign.
	phase_x := -x.phase % tile_width
	phase_y := -y.phase % tile_height
	tile_x := dest_x + phase_x
	tile_y := dest_y + phase_y
	if tile_x > dest_x || tile_y > dest_y || dest_x + unsnapped_width > tile_x + tile_width
		|| dest_y + unsnapped_height > tile_y + tile_height {
		return none
	}
	scale_x := chromium_layout_unit_to_float(tile_width) / f32(natural_width)
	scale_y := chromium_layout_unit_to_float(tile_height) / f32(natural_height)
	source := chromium_snap_source_rect(painting.Rect{
		x: f64(chromium_layout_unit_to_float(dest_x - tile_x) / scale_x)
		y: f64(chromium_layout_unit_to_float(dest_y - tile_y) / scale_y)
		width: f64(chromium_layout_unit_to_float(unsnapped_width) / scale_x)
		height: f64(chromium_layout_unit_to_float(unsnapped_height) / scale_y)
	})
	unit := f64(chromium_layout_unit)
	return ChromiumSingleTileBackground{
		destination: painting.Rect{f64(dest_x) / unit, f64(dest_y) / unit, f64(dest_width) / unit,
			f64(dest_height) / unit}
		source: source
		// BoxPainterBase preserves filtering for a whole snapped tile, while
		// sprite subsets retain their strict source boundary.
		unclamped_source: tile_width == dest_width && tile_height == dest_height
	}
}
