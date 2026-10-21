module layout

import math
import platform

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
	count := result.paint_order.len
	mut selected := unsafe { result.record_scratch.visible_entries }
	if selected.cap < count {
		selected = []bool{cap: count}
	}
	selected.clear()
	for _ in 0 .. count {
		selected << true
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
	for index, entry in result.paint_order {
		box := entry.box
		if !viewport_entry_has_bounded_ink(box) { continue }
		if box.paintable_with_lines && box.accumulated_visual_context_index
			!= box.accumulated_visual_context_for_descendants_idx { continue }
		slot := contexts.resolve(box.accumulated_visual_context_index)
		context := unsafe { &contexts.contexts[slot] }
		if context.layer_list != unsafe { nil } { continue }
		if viewport_box_ink_is_outside(box, context.transform, width, height, mut ink_probe) {
			selected[index] = false
		}
	}
}

fn viewport_entry_has_bounded_ink(box &BlockBox) bool {
	return !box.has_svg_path && box.svg_mask == none && box.svg_clip == none
		&& !box.filter.has_filters() && !box.backdrop_filter.has_filters()
		&& box.shadow == none && box.shadows.len == 0
		&& box.background_images.len == 0 && box.background_gradient == none
		&& box.replaced_image_url == '' && box.replaced_image_paintable == none
		&& box.canvas_bitmap == none && box.canvas_paintable == none
		&& box.video_bitmap == none && box.video_paintable == none
		&& box.nested_viewport_document == none && box.nested_viewport_paintable == none
		&& box.fieldset_paintable == none && box.form_control_kind == ''
		&& !box.table_inside && !box.uses_collapsed_borders
		&& box.overlay == none && box.marker_shape == ''
		&& box.fixed_background_visual_context == none
}

fn viewport_rect_is_outside(rect LayoutRect, transform [6]f64, width f64, height f64,
	mut ink_probe PaintCommand) bool {
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
	outset := math.max(f64(0), box.outline_width + math.abs(box.outline_offset)) + 2
	if !viewport_rect_is_outside(LayoutRect{border.x - outset, border.y - outset,
		border.width + outset * 2, border.height + outset * 2}, transform, width, height, mut ink_probe) {
		return false
	}
	if box.paints_canvas_background && !viewport_rect_is_outside(
		LayoutRect{box.canvas_x, box.canvas_y, box.canvas_width, box.canvas_height},
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
