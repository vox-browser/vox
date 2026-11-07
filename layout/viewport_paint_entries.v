module layout

import math
import os
import platform

const disable_direct_viewport_rect_culling = os.getenv('VOX_DISABLE_DIRECT_VIEWPORT_RECT_CULLING') != ''
const disable_bounded_image_entries = os.getenv('VOX_DISABLE_BOUNDED_IMAGE_ENTRIES') != ''

// Culling resolves a flattened visual context for every bounded entry on each
// viewport recording. Those temporaries live in this arena, reset as soon as
// the selection is known.
__global viewport_visible_entries_scratch_ = &platform.Arena(unsafe { nil })

// Cull individual paintables, never descendants on the strength of a parent's
// border box. Overflowing, transformed and fixed descendants remain separate
// entries. Effect/resource inputs stay complete even when their source is off
// screen: a filter or mask can move or generate visible pixels from them.
// The selection reuses the result's recording scratch until the next one.
fn viewport_visible_paint_entries(mut result DocumentLayoutResult) []bool {
	if !disable_viewport_ink_cache {
		refresh_viewport_entry_ink_cache(mut result)
		if !disable_viewport_entry_blocks { refresh_viewport_entry_blocks(mut result) }
	}
	count := result.paint_order.len
	mut selected := unsafe { result.record_scratch.visible_entries }
	if selected.cap < count {
		selected = []bool{cap: count}
	}
	// Every entry starts selected; fill the reused storage in one pass.
	unsafe {
		selected.len = count
		vmemset(selected.data, 1, count)
	}
	result.record_scratch.visible_entries = selected
	viewport := result.document.viewport_rect()
	if viewport.width <= 0 || viewport.height <= 0 { return selected }
	// A nested document records inside its parent's arena and allocates there.
	if platform.transient_arena_entered() {
		mark_viewport_invisible_entries(result, mut selected, viewport.width, viewport.height)
		return selected
	}
	if viewport_visible_entries_scratch_ == unsafe { nil } {
		persistent := platform.enter_persistent()
		viewport_visible_entries_scratch_ = platform.new_arena('viewport visible entries')
		platform.leave_persistent(persistent)
	}
	mut scratch := viewport_visible_entries_scratch_
	entry := scratch.enter()
	mark_viewport_invisible_entries(result, mut selected, viewport.width, viewport.height)
	scratch.leave(entry)
	scratch.reset()
	return selected
}

fn mark_viewport_invisible_entries(result &DocumentLayoutResult, mut selected []bool, width f64, height f64) {
	mut contexts := new_compatibility_visual_context_memo(&result.visual_context_tree,
		result.scroll_state_snapshot)
	// The bounds helper borrows a command. Reuse one probe for the traversal:
	// taking the address of a fresh local makes current V allocate a complete
	// command for every box and text fragment, even in Boehm builds.
	mut ink_probe := PaintCommand{}
	cache := &result.record_scratch.viewport_ink_cache
	if !disable_viewport_ink_cache && !disable_viewport_entry_blocks && cache.blocks_valid
		&& cache.blocks_revision == cache.revision && cache.testable.len == result.paint_order.len {
		for block in cache.blocks {
			if block.testable == 0 { continue }
			if block.cullable && !disable_viewport_ink_bounds && !disable_direct_viewport_rect_culling {
				slot := contexts.resolve(block.context)
				context := unsafe { &contexts.contexts[slot] }
				// The per-entry pass keeps every entry of a layered context.
				if context.layer_list != unsafe { nil } { continue }
				mut transform := context.transform
				mut area_height := height
				if block.prepaint {
					transform = viewport_prepaint_transform(context.transform, height)
					area_height = height * 3
				}
				if viewport_rect_is_outside(block.bounds, transform, width, area_height, mut ink_probe) {
					for index in block.first .. block.first + block.count {
						if cache.testable[index] { selected[index] = false }
					}
					continue
				}
			}
			for index in block.first .. block.first + block.count {
				mark_viewport_invisible_entry(result, index, mut contexts, mut selected, width,
					height, mut ink_probe)
			}
		}
		return
	}
	for index in 0 .. result.paint_order.len {
		mark_viewport_invisible_entry(result, index, mut contexts, mut selected, width, height, mut
			ink_probe)
	}
}

fn mark_viewport_invisible_entry(result &DocumentLayoutResult, index int,
	mut contexts CompatibilityVisualContextMemo, mut selected []bool, width f64, height f64,
	mut ink_probe PaintCommand) {
	box := result.paint_order[index].box
	if !disable_viewport_ink_cache {
		if !result.record_scratch.viewport_ink_cache.entries[index].bounded { return }
	} else if !viewport_entry_has_bounded_ink(box) { return }
	if box.paintable_with_lines && box.accumulated_visual_context_index
		!= box.accumulated_visual_context_for_descendants_idx { return }
	slot := contexts.resolve(box.accumulated_visual_context_index)
	context := unsafe { &contexts.contexts[slot] }
	if context.layer_list != unsafe { nil } { return }
	prepaint := if disable_viewport_ink_cache {
		viewport_entry_paints_images(box)
	} else {
		result.record_scratch.viewport_ink_cache.entries[index].prepaint
	}
	mut transform := context.transform
	mut area_height := height
	if prepaint {
		transform = viewport_prepaint_transform(context.transform, height)
		area_height = height * 3
	}
	outside := if disable_viewport_ink_cache {
		viewport_box_ink_is_outside(box, transform, width, area_height, mut ink_probe)
	} else {
		viewport_cached_entry_ink_is_outside(&result.record_scratch.viewport_ink_cache,
			index, transform, width, area_height, mut ink_probe)
	}
	if outside {
		selected[index] = false
	}
}

fn viewport_entry_has_bounded_ink(box &BlockBox) bool {
	return !box.has_svg_path() && box.clips().svg_mask == none && box.clips().svg_clip == none
		&& !box.filters().filter.has_filters() && !box.filters().backdrop_filter.has_filters()
		&& box.decorations().shadow == none && box.decorations().shadows.len == 0
		&& viewport_entry_background_is_bounded(box) && viewport_entry_replaced_image_is_bounded(box)
		&& box.media().canvas_bitmap == none && box.media().canvas_paintable == none
		&& box.media().video_bitmap == none && box.media().video_paintable == none
		&& box.media().nested_viewport_document == none && box.media().nested_viewport_paintable == none
		&& box.media().fieldset_paintable == none && box.media().form_control_kind == ''
		&& !box.table_inside && !box.uses_collapsed_borders
		&& box.overlay == none && box.marker_shape == ''
		&& box.fixed_background_visual_context == none
}

// Backgrounds paint inside their background painting area, which never
// extends beyond the border box, so its cached ink bounds them. Comment
// trees use a background arrow and a spacer image on every row; keeping each
// one recorded made long threads replay thousands of offscreen commands per
// scrolled frame. Fixed attachment (excluded above) and the propagated canvas
// background keep the complete path.
fn viewport_entry_background_is_bounded(box &BlockBox) bool {
	if box.decorations().background_images.len == 0 && box.decorations().background_gradient == none {
		return true
	}
	return !disable_bounded_image_entries && !box.canvas().paints_canvas_background
}

// An <img> paints its bitmap clipped to the content box (image_clip_*), and the
// element fetches its own source. Broken-image fallbacks and SVG documents
// keep the complete path.
fn viewport_entry_replaced_image_is_bounded(box &BlockBox) bool {
	media := box.media()
	if media.replaced_image_url == '' && media.replaced_image_paintable == none { return true }
	if disable_bounded_image_entries || media.is_svg_image || media.nested_viewport_document != none {
		return false
	}
	if paintable := media.replaced_image_paintable {
		if paintable.broken_image_fallback_scale > 0 { return false }
	}
	return true
}

// Background images are requested and images decoded when first replayed.
// Like Chromium's interest area beyond the viewport, keep such entries
// recorded within one viewport height above and below it so their pixels are
// ready before they scroll in.
fn viewport_entry_paints_images(box &BlockBox) bool {
	return box.decorations().background_images.len > 0 || box.media().replaced_image_url != ''
		|| box.media().replaced_image_paintable != none
}

// Map into a canvas extended by `margin` above and below the viewport.
fn viewport_prepaint_transform(transform [6]f64, margin f64) [6]f64 {
	mut matrix := normalized_affine(transform)
	matrix[5] += margin
	return matrix
}

fn viewport_rect_is_outside(rect LayoutRect, transform [6]f64, width f64, height f64,
	mut ink_probe PaintCommand) bool {
	if !disable_direct_viewport_rect_culling {
		return viewport_rect_outside_native_canvas(rect, transform, width, height)
	}
	ink_probe = PaintCommand{
		kind: 'fill_rect'
		x: rect.x
		y: rect.y
		width: rect.width
		height: rect.height
		transform: transform
	}
	return paint_leaf_is_outside_canvas(ink_probe, 0, 0, width, height)
}

fn viewport_box_ink_is_outside(box &BlockBox, transform [6]f64, width f64, height f64,
	mut ink_probe PaintCommand) bool {
	border := box.border_box()
	// Includes native antialiasing, negative outline offsets and auto rings.
	outset := math.max(f64(0), box.decorations().outline_width + math.abs(box.decorations().outline_offset)) + 2
	if !viewport_rect_is_outside(LayoutRect{border.x - outset, border.y - outset,
		border.width + outset * 2, border.height + outset * 2}, transform, width, height, mut ink_probe) {
		return false
	}
	if box.canvas().paints_canvas_background && !viewport_rect_is_outside(
		LayoutRect{box.canvas().canvas_x, box.canvas().canvas_y, box.canvas().canvas_width, box.canvas().canvas_height},
		transform, width, height, mut ink_probe) { return false }
	for line in box.lines {
		for index in 0 .. line.fragments.len {
			if !viewport_fragment_ink_is_outside(unsafe { &line.fragments[index] }, transform,
				width, height, mut ink_probe) { return false }
		}
		for index in 0 .. line.box_decorations.len {
			if !viewport_fragment_ink_is_outside(unsafe { &line.box_decorations[index] }, transform,
				width, height, mut ink_probe) { return false }
		}
	}
	return true
}

fn viewport_fragment_ink_is_outside(fragment &TextFragment, transform [6]f64,
	width f64, height f64, mut ink_probe PaintCommand) bool {
	if fragment.shadow != none || fragment.shadows.len > 0 || fragment.text_shadows.len > 0
		|| fragment.selection_style.text_shadows.len > 0 || fragment.background_images.len > 0
		|| fragment.paintable_fragment.orientation != .horizontal
		|| (fragment.text != '' && !fragment.baseline_set) { return false }
	mut outset := math.max(f64(0), fragment.outline_width + math.abs(fragment.outline_offset)) + 2
	if fragment.decoration != 'none' || fragment.selection_style.decoration_set {
		if !fragment.font_metrics_set { return false }
		// Every underline/overline/strike path is relative to the retained
		// baseline. Include its full metric range, explicit offset, and the
		// double/wavy stroke extent before applying the native precision guard.
		outset += math.abs(fragment.baseline) + math.abs(fragment.font_ascent)
			+ math.abs(fragment.font_descent) + math.abs(fragment.glyph_height)
			+ math.abs(fragment.font_size) + math.abs(fragment.text_underline_offset)
			+ 4 * math.max(f64(1), math.abs(fragment.decoration_thickness))
	}
	left := fragment.x - fragment.padding.left - fragment.border.left - outset
	top := fragment.y - fragment.padding.top - fragment.border.top - outset
	right := fragment.x + fragment.width + fragment.padding.right + fragment.border.right + outset
	bottom := fragment.y + fragment.height + fragment.padding.bottom + fragment.border.bottom + outset
	if !viewport_rect_is_outside(LayoutRect{left, top, right - left, bottom - top},
		transform, width, height, mut ink_probe) { return false }
	if fragment.text == '' { return true }
	run := fragment.paintable_fragment.glyph_run or { return false }
	ink_probe = PaintCommand{
		kind: 'draw_text'
		glyph_run: run
		glyph_translation_x: fragment.x
		glyph_translation_y: text_fragment_paint_top(*fragment) + fragment.baseline
		transform: transform
	}
	return paint_leaf_is_outside_canvas(ink_probe, 0, 0, width, height)
}
