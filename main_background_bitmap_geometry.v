module main

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
