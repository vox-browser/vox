module layout

import dom
import math
import os
import painting

// Rejection reasons print with -d vox_scroll_raster_diagnostics, or at run
// time in any build with VOX_SCROLL_RASTER_DAMAGE_DIAGNOSTICS set.
const scroll_raster_reject_diagnostics = os.getenv('VOX_SCROLL_RASTER_DAMAGE_DIAGNOSTICS') != ''
const scrollbar_paint_diagnostics = os.getenv('VOX_SCROLLBAR_PAINT_DIAGNOSTICS') != ''

// VOX_SCROLLBAR_PAINT_DIAGNOSTICS: the element that owns each painted scrollbar,
// with its padding box and scrollable overflow in paint-tree units.
fn (b &BlockBox) report_painted_scrollbar(overlay CompatibilityOverlayData, padding painting.Rect) {
	mut name := 'node${b.node_id}'
	if b.node_id != 0 {
		if node := dom.Node.from_unique_id(dom.UniqueNodeID(b.node_id)) {
			if element := node.as_element() {
				name = '${element.local_name()}#${element.get_attribute('id') or { '' }}.${element.get_attribute('class') or { '' }}'
			} else {
				name = node.node_name()
			}
		}
	}
	eprintln('VOX_SCROLLBAR_PAINT box=${name} viewport=${b.is_viewport_scroller} padding=${padding.x},${padding.y},${padding.width}x${padding.height} overflow=${overlay.scrollable_overflow.x},${overlay.scrollable_overflow.y},${overlay.scrollable_overflow.width}x${overlay.scrollable_overflow.height} vertical=${overlay.can_scroll_vertically} horizontal=${overlay.can_scroll_horizontally} width=${overlay.scrollbar_width}')
}

@[inline]
fn reject_scroll_raster(reason string) bool {
	$if vox_scroll_raster_diagnostics ? {
		eprintln('VOX_SCROLL_RASTER_REJECT reason=${reason}')
	} $else {
		if scroll_raster_reject_diagnostics {
			eprintln('VOX_SCROLL_RASTER_REJECT reason=${reason}')
		}
	}
	return false
}

// A rejected scrollbar's command and position, built only when rejection
// reasons print: the eligibility check runs on every scrolled frame.
fn scroll_raster_scrollbar_reason(reason string, index int, count int, kind string,
	bounds LayoutRect, width f64, height f64) string {
	mut detailed := scroll_raster_reject_diagnostics
	$if vox_scroll_raster_diagnostics ? {
		detailed = true
	}
	if !detailed { return reason }
	return '${reason}:${index}/${count}:${kind}:${bounds.x},${bounds.y},${bounds.width}x${bounds.height}:viewport=${width}x${height}'
}

// Shadow commands keep their own blur radius; every other blurred or
// portable-shadow leaf still needs complete replay.
fn scroll_raster_shadow_kind(kind string) bool {
	return kind in ['paint_outer_box_shadow', 'paint_inner_box_shadow', 'draw_text_shadow',
		'fill_inset_shadow']
}

// Leaves whose clipped replay reproduces exactly the pixels of a complete
// replay: they translate with the viewport and write only inside their ink.
fn scroll_raster_translating_leaf(kind string) bool {
	return kind in ['fill_rect', 'fill_rounded_rect', 'stroke_rounded_rect', 'fill_ellipse',
		'stroke_ellipse', 'paint_uniform_border', 'draw_line', 'fill_polygon', 'draw_text',
		'paint_rounded_border_top', 'paint_rounded_border_right', 'paint_partial_rounded_border',
		'paint_rounded_border_bottom', 'paint_rounded_border_left', 'draw_replaced_image',
		'draw_background_image', 'draw_svg_path', 'draw_svg_image', 'fill_gradient',
		'fill_rect_transparent', 'paint_outer_box_shadow', 'paint_inner_box_shadow',
		'draw_text_shadow', 'fill_inset_shadow', 'draw_video', 'draw_canvas',
		'paint_nested_display_list']
}

// Group boundaries whose native implementation composites under the current
// clip: opacity/blend layers and background text clips are per-pixel, and a
// CSS filter layer renders its complete source into a separate full-canvas
// surface before compositing the filtered result under the clip. SVG filter
// graphs, masks and backdrop filters keep complete replay.
pub fn scroll_raster_group_begin(kind string) bool {
	return kind in ['begin_css_effect_layer', 'begin_css_filter_layer',
		'begin_background_text_clip', 'begin_background_blend_group']
}

pub fn scroll_raster_group_end(kind string) string {
	return match kind {
		'begin_css_effect_layer' { 'end_css_effect_layer' }
		'begin_css_filter_layer' { 'end_css_filter_layer' }
		'begin_background_text_clip' { 'end_background_text_clip' }
		'begin_background_blend_group' { 'end_background_blend_group' }
		else { '' }
	}
}

fn scroll_raster_filter_supported(command &PaintCommand) bool {
	filter := command.visual_layer().filter or { return true }
	if filter.nodes.len > 0 || filter.root_id != none { return false }
	for operation in filter.operations {
		for value in [operation.first, operation.second, operation.third] {
			if math.is_nan(value) || math.is_inf(value, 0) { return false }
		}
	}
	return true
}

// Ordinary leaves and groups can reuse viewport pixels. Fixed, sticky and
// scroll-compensated content does not translate with the viewport, but its
// retained transform lacks the scroll offset, so the scroll-compensated
// content keys of every scrolled frame mark it changed and the damage covers
// both its vacated and its current rectangles. Resource/effect inputs and
// perspective contexts keep complete replay. Check the whole property tree,
// including currently offscreen boxes.
pub fn viewport_scroll_raster_reusable(document &dom.Document, commands []PaintCommand,
	width f64, height f64) bool {
	result := document_layout_result(document) or { return reject_scroll_raster('missing-layout') }
	for node in result.visual_context_tree.nodes {
		if node.data is painting.PerspectiveVisualData {
			return reject_scroll_raster('perspective')
		}
	}
	mut in_command_group := false
	mut open_groups := []string{}
	// Only the trailing viewport overlays are painted after caching. Nested
	// scrollers' bars earlier in the list translate with their content; their
	// overlay fade enters the content keys, so a fade repaints them as damage.
	trailing_start := scroll_raster_trailing_scrollbar_start(commands)
	for index in 0 .. commands.len {
		// Read-only helpers borrow the retained command instead of boxing a copy.
		command := unsafe { &commands[index] }
		if command.scrollbar_axis != '' {
			if in_command_group || open_groups.len > 0 { return reject_scroll_raster('scrollbar-in-group') }
			if index < trailing_start {
				if command.kind !in ['fill_rect', 'fill_rounded_rect', 'stroke_rounded_rect'] {
					return reject_scroll_raster('nested-scrollbar-kind')
				}
				continue
			}
			bounds := compatibility_affine_map_rect(command.transform,
				LayoutRect{command.x, command.y, command.width, command.height})
			if command.scrollbar_axis == 'vertical' {
				if bounds.x < width - 30 || bounds.x + bounds.width > width + 1 {
					return reject_scroll_raster(scroll_raster_scrollbar_reason('nonviewport-vertical-scrollbar',
						index, commands.len, command.kind, bounds, width, height))
				}
			} else if command.scrollbar_axis != 'horizontal' || bounds.y < height - 30 || bounds.y + bounds.height > height + 1 {
				return reject_scroll_raster(scroll_raster_scrollbar_reason('nonviewport-horizontal-scrollbar',
					index, commands.len, command.kind, bounds, width, height))
			}
			continue
		}
		if command.outer_shadow { return reject_scroll_raster('outer-shadow') }
		if command.blur != 0 && !scroll_raster_shadow_kind(command.kind) { return reject_scroll_raster('blur') }
		if scroll_raster_translating_leaf(command.kind) { continue }
		if scroll_raster_group_begin(command.kind) {
			if command.kind == 'begin_css_filter_layer' && !scroll_raster_filter_supported(command) {
				return reject_scroll_raster('svg-filter')
			}
			open_groups << scroll_raster_group_end(command.kind)
			continue
		}
		if open_groups.len > 0 && command.kind == open_groups.last() {
			open_groups.pop()
			continue
		}
		match command.kind {
			// Controls composite these translating primitives on one Skia
			// surface. Replay both boundaries before caching the final pixels.
			'begin_skia_command_group' {
				if in_command_group { return reject_scroll_raster('nested-group') }
				in_command_group = true
			}
			'end_skia_command_group' {
				if !in_command_group { return reject_scroll_raster('unmatched-group-end') }
				in_command_group = false
			}
			else {
				$if vox_scroll_raster_diagnostics ? {
					eprintln('VOX_SCROLL_RASTER_COMMAND kind=${command.kind} bounds=${command.x},${command.y},${command.width},${command.height} transform=${command.transform}')
				}
				return reject_scroll_raster('unsupported-command:${command.kind}')
			}
		}
	}
	if commands.len == 0 { return reject_scroll_raster('empty-commands') }
	if in_command_group || open_groups.len > 0 { return reject_scroll_raster('unclosed-group') }
	return true
}

// Index of the first command in the trailing run of scrollbar commands, or
// the list length when the list does not end with scrollbars.
pub fn scroll_raster_trailing_scrollbar_start(commands []PaintCommand) int {
	mut start := commands.len
	for start > 0 && commands[start - 1].scrollbar_axis != '' {
		start--
	}
	return start
}

// Conservative viewport-space ink of one leaf for scroll damage decisions,
// including the kinds admitted above that the generic effect bounds decline.
// Outer shadows extend two blur radii beyond their shadow rectangle, matching
// native replay culling; inner shadows stay inside their content box.
pub fn scroll_raster_leaf_ink_bounds(command &PaintCommand) ?LayoutRect {
	match command.kind {
		'paint_outer_box_shadow', 'draw_text_shadow' {
			if command.blur < 0 || math.is_nan(command.blur) || math.is_inf(command.blur, 0) { return none }
			margin := command.blur * 2.0
			source := PaintCommand{
				kind:      'fill_rect'
				x:         command.x - margin
				y:         command.y - margin
				width:     command.width + margin * 2.0
				height:    command.height + margin * 2.0
				transform: command.transform
			}
			return effect_leaf_ink_bounds_with_precision_guard(&source, true)
		}
		'paint_inner_box_shadow' {
			mut rect := LayoutRect{command.x, command.y, command.width, command.height}
			if command.box_shadow_data != unsafe { nil } {
				rect = command.box_shadow_data.content_rect
			}
			source := PaintCommand{
				kind:      'fill_rect'
				x:         rect.x
				y:         rect.y
				width:     rect.width
				height:    rect.height
				transform: command.transform
			}
			return effect_leaf_ink_bounds_with_precision_guard(&source, true)
		}
		'paint_uniform_border', 'paint_partial_rounded_border', 'paint_rounded_border_top',
		'paint_rounded_border_right', 'paint_rounded_border_bottom', 'paint_rounded_border_left',
		'draw_svg_path' {
			// Borders paint inside their border box; SVG paths record their path
			// bounds, which a stroke can extend by its width.
			margin := if command.kind == 'draw_svg_path' {
				math.max(command.stroke_width, 0.0) * 2.0 + 2.0
			} else {
				1.0
			}
			if math.is_nan(margin) || math.is_inf(margin, 0) { return none }
			source := PaintCommand{
				kind:      'fill_rect'
				x:         command.x - margin
				y:         command.y - margin
				width:     command.width + margin * 2.0
				height:    command.height + margin * 2.0
				transform: command.transform
			}
			return effect_leaf_ink_bounds_with_precision_guard(&source, true)
		}
		'fill_inset_shadow', 'draw_video', 'draw_canvas', 'fill_rect_transparent' {
			source := PaintCommand{
				kind:      'fill_rect'
				x:         command.x - 1
				y:         command.y - 1
				width:     command.width + 2
				height:    command.height + 2
				transform: command.transform
			}
			return effect_leaf_ink_bounds_with_precision_guard(&source, true)
		}
		else {}
	}
	return effect_leaf_ink_bounds_with_precision_guard(command, true)
}

// Extra viewport-space extent a CSS filter layer adds around its source ink:
// Gaussian blurs reach three sigma, drop shadows add their offset. Color
// filters move no pixels. none means the extent is not bounded.
pub fn scroll_raster_filter_extent(command &PaintCommand) ?f64 {
	filter := command.visual_layer().filter or { return 0.0 }
	if filter.nodes.len > 0 || filter.root_id != none { return none }
	mut extent := 0.0
	for operation in filter.operations {
		match operation.kind {
			'blur' {
				if operation.first < 0 || math.is_nan(operation.first) { return none }
				extent += operation.first * 3.0
			}
			'drop-shadow' {
				for value in [operation.first, operation.second, operation.third] {
					if math.is_nan(value) || math.is_inf(value, 0) { return none }
				}
				extent += math.abs(operation.first) + math.abs(operation.second)
					+ math.max(operation.third, 0.0) * 3.0
			}
			'color', 'hue-rotate', 'grayscale', 'sepia', 'saturate', 'brightness', 'contrast',
			'invert', 'opacity' {}
			else { return none }
		}
	}
	return extent + 1.0
}

// Whether a filter layer's output at a pixel depends only on that pixel's
// source: children outside the damage may then be skipped individually.
pub fn scroll_raster_filter_is_pointwise(command &PaintCommand) bool {
	extent := scroll_raster_filter_extent(command) or { return false }
	return extent <= 1.0
}

pub fn scroll_raster_rect_union(first ?LayoutRect, second ?LayoutRect) ?LayoutRect {
	a := first or { return second }
	b := second or { return a }
	return rect_union(a, b)
}

pub fn scroll_raster_rect_intersect(first LayoutRect, second LayoutRect) LayoutRect {
	return compatibility_intersect_rects(first, second)
}

pub fn scroll_raster_map_rect(transform [6]f64, rect LayoutRect) LayoutRect {
	return compatibility_affine_map_rect(transform, rect)
}

pub fn scroll_raster_normalized_transform(transform [6]f64) [6]f64 {
	return normalized_affine(transform)
}

// The viewport scroll offset in CSS pixels exactly as recorded commands apply
// it. The scroll state snapshot stores each frame's layout-space offset in f32,
// as upstream's Gfx float vectors do. An unzoomed viewport scrolls by whole
// device pixels, which f32 represents exactly. Page zoom scrolls by fractional
// CSS pixels, and their recorded translation keeps an f32 rounding. Retained
// raster keys remove the scroll translation from each command; removing the
// unrounded offset instead would leave a residue that changes every frame.
pub fn scroll_raster_recorded_viewport_scroll(document &dom.Document) f64 {
	scale := document.layout_coordinate_scale()
	// viewport_rederive_scroll_state() negates the live layout-space offset
	// and ScrollStateSnapshot.create() rounds it through f32 at scale 1.
	recorded := f64(f32(-document.layout_viewport_rect().y) * f32(1.0))
	return -recorded / scale
}
