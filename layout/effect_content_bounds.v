module layout

import math

// The ancestor clip can cover the entire viewport even for a tiny opacity
// group. Bound its surface by the union of its painted children instead.
// Unknown operations and filter inputs retain the original ancestor bounds.
struct EffectContentBounds {
mut:
	begin   int
	filter_depth int
	bounded bool = true
	has_ink bool
	ink     LayoutRect
}

// CSS color matrices and hue rotation leave transparent input transparent
// and do not move ink. SVG graphs, blurs and shadows need their full inputs.
fn effect_filter_preserves_ink_bounds(command &PaintCommand) bool {
	filter := command.visual_layer().filter or { return false }
	if filter.nodes.len > 0 || filter.root_id != none { return false }
	for operation in filter.operations {
		if operation.kind !in ['color', 'hue-rotate'] { return false }
		for value in [operation.first, operation.second, operation.third] {
			if math.is_nan(value) || math.is_inf(value, 0) { return false }
		}
	}
	return true
}

fn (mut bounds EffectContentBounds) include(rect LayoutRect) {
	if rect.width <= 0 || rect.height <= 0 { return }
	bounds.ink = if bounds.has_ink { rect_union(bounds.ink, rect) } else { rect }
	bounds.has_ink = true
}

fn effect_leaf_ink_bounds(command &PaintCommand) ?LayoutRect {
	return effect_leaf_ink_bounds_with_precision_guard(command, false)
}

fn effect_leaf_ink_bounds_with_precision_guard(command &PaintCommand, native_precision bool) ?LayoutRect {
	mut rect := LayoutRect{command.x, command.y, command.width, command.height}
	mut outset := f64(0)
	match command.kind {
		'fill_rect', 'fill_rounded_rect', 'fill_ellipse', 'begin_background_text_clip',
		'draw_svg_image' {
			if command.outer_shadow || command.blur != 0 { return none }
		}
		'draw_replaced_image' {
			if command.outer_shadow || command.blur != 0 { return none }
			// Replay clips the fitted image to its retained paintable rectangle.
			// The compatibility command can still carry the unshifted box bounds
			// (notably for inline images), which can cull visible thumbnail rows.
			image := command.image_paintable or { return none }
			rect = LayoutRect{image.image_rect.x, image.image_rect.y,
				image.image_rect.width, image.image_rect.height}
			outset = 1
		}
		'draw_background_image' {
			// Background origin and clip may differ (for example padding-box
			// positioning with border-box painting). The clip owns the output.
			image := command.image_data
			if image == unsafe { nil } { return none }
			rect = LayoutRect{image.image_clip_x, image.image_clip_y, image.image_clip_width, image.image_clip_height}
			// Bitmap background edges are snapped in source space before the
			// transform. Retain that fringe even with large CSS scales.
			outset = 1
		}
		'fill_gradient' {
			if command.gradient_background_layer {
				image := command.image_data
				if image == unsafe { nil } { return none }
				rect = LayoutRect{image.image_clip_x, image.image_clip_y, image.image_clip_width, image.image_clip_height}
			}
		}
		'stroke_rounded_rect', 'stroke_ellipse' {
			if command.points.len > 0 { return none }
			outset = math.max(f64(0), command.stroke_width)
		}
		'draw_line', 'fill_polygon' {
			if command.points.len < 4 || command.points.len % 2 != 0 { return none }
			mut left := command.points[0]
			mut right := left
			mut top := command.points[1]
			mut bottom := top
			for index := 2; index < command.points.len; index += 2 {
				left = math.min(left, command.points[index])
				right = math.max(right, command.points[index])
				top = math.min(top, command.points[index + 1])
				bottom = math.max(bottom, command.points[index + 1])
			}
			rect = LayoutRect{left, top, right - left, bottom - top}
			outset = math.max(f64(0), command.stroke_width)
		}
		'draw_text' {
			if command.glyph_orientation != .horizontal { return none }
			run := command.glyph_run or { return none }
			if native_precision && (math.abs(command.glyph_translation_x) > 1_000_000
				|| math.abs(command.glyph_translation_y) > 1_000_000) { return none }
			ink := run.bounding_box()
			rect = LayoutRect{command.glyph_translation_x + f64(ink.x), command.glyph_translation_y + f64(ink.y), f64(ink.width), f64(ink.height)}
		}
		else { return none }
	}
	rect = LayoutRect{rect.x - outset, rect.y - outset, rect.width + outset * 2, rect.height + outset * 2}
	if native_precision {
		// Native drawing rounds its geometry and matrix to float32. Large
		// cancelling coordinates can move ink across the canvas edge; retain
		// those draws rather than relying on the float64 replay bounds.
		matrix := normalized_affine(command.transform)
		mut scale := f64(1)
		for index in 0 .. 6 {
			if math.is_nan(matrix[index]) || math.is_inf(matrix[index], 0) { return none }
			if index < 4 { scale = math.max(scale, math.abs(matrix[index])) }
		}
		if math.abs(matrix[4]) > 1_000_000 || math.abs(matrix[5]) > 1_000_000 { return none }
		for value in [rect.x, rect.y, rect.x + rect.width, rect.y + rect.height]! {
			if math.abs(value) * scale > 1_000_000 { return none }
		}
	}
	mapped := compatibility_affine_map_rect(command.transform, rect)
	for value in [mapped.x, mapped.y, mapped.width, mapped.height]! {
		if math.is_nan(value) || math.is_inf(value, 0) { return none }
	}
	return mapped
}

// Ordinary leaves and a text clip's final output rectangle are eligible.
// Callers discard a text clip only as a complete group; individual source
// pixels inside a resource/filter group can still contribute visible output.
pub fn paint_leaf_is_outside_canvas(command &PaintCommand, page_x f64, page_y f64,
    width f64, height f64) bool {
    if command.outer_shadow || command.blur != 0 || width <= 0 || height <= 0 { return false }
    for value in [page_x, page_y, width, height]! {
        if math.is_nan(value) || math.is_inf(value, 0) || math.abs(value) > 1_000_000 { return false }
    }
    bounds := effect_leaf_ink_bounds_with_precision_guard(command, true) or { return false }
    if bounds.width <= 0 || bounds.height <= 0 { return false }
    // Keep an extra CSS-pixel fringe beyond the native raster guards, including
    // fractional transforms and antialiased clips at either backing density.
    return bounds.x + page_x > width + 3 || bounds.y + page_y > height + 3
        || bounds.x + bounds.width + page_x < -3 || bounds.y + bounds.height + page_y < -3
}

fn bound_visual_effect_contents(mut commands []PaintCommand) {
	mut stack := []EffectContentBounds{}
	mut filters := []bool{}
	for index in 0 .. commands.len {
		command := unsafe { &commands[index] }
		if command.kind == 'begin_css_filter_layer' {
			bounded := effect_filter_preserves_ink_bounds(command)
			filters << bounded
			if stack.len > 0 && !bounded { stack[stack.len - 1].bounded = false }
			continue
		}
		if command.kind == 'end_css_filter_layer' {
			if filters.len == 0 {
				if stack.len > 0 { stack[stack.len - 1].bounded = false }
			} else { filters.pop() }
			continue
		}
		if command.kind == 'begin_css_effect_layer' {
			stack << EffectContentBounds{
				begin:   index
				filter_depth: filters.len
				bounded: command.visual_layer().blend_mode == .normal
			}
			continue
		}
		if stack.len == 0 { continue }
		if command.kind == 'end_css_effect_layer' {
			mut bounds := stack.pop()
			if bounds.filter_depth != filters.len { bounds.bounded = false }
			if bounds.bounded {
				mut begin := unsafe { &commands[bounds.begin] }
				mut ink := bounds.ink
				if begin.has_clip {
					ink = compatibility_intersect_rects(ink, LayoutRect{begin.clip_x, begin.clip_y, begin.clip_width, begin.clip_height})
				}
				begin.has_clip = true
				begin.clip_x = ink.x
				begin.clip_y = ink.y
				begin.clip_width = ink.width
				begin.clip_height = ink.height
			}
			if stack.len > 0 {
				if bounds.bounded {
					stack[stack.len - 1].include(bounds.ink)
				} else {
					stack[stack.len - 1].bounded = false
				}
			}
			continue
		}
		if !stack[stack.len - 1].bounded { continue }
		if ink := effect_leaf_ink_bounds(command) {
			stack[stack.len - 1].include(ink)
		} else {
			// In particular, a nested filter may move or generate pixels beyond
			// all its input commands. Do not constrain that enclosing surface.
			stack[stack.len - 1].bounded = false
		}
	}
}
