module layout

import crypto.sha256
import json2
import math
import os
import strings

pub const page_switch_tile_size = 128

// Owned values only: the previous document, layout and glyph arena can be
// retired before these signatures are compared with the replacement page.
pub struct PageSwitchTiles {
pub:
	width  int
	height int
	keys   []string
}

// Canonical process-local bytes, without pointer values or struct padding.
// This helper is instantiated only for the explicitly accepted value fields.
fn page_switch_write[T](mut key strings.Builder, value T) {
	$if T is string {
		length := u64(value.len)
		unsafe { key.write_ptr(&u8(&length), sizeof(length)) }
		key.write_string(value)
	} $else $if T is $array {
		length := u64(value.len)
		unsafe { key.write_ptr(&u8(&length), sizeof(length)) }
		for item in value { page_switch_write(mut key, item) }
	} $else $if T is $struct {
		$for field in T.fields { page_switch_write(mut key, value.$(field.name)) }
	} $else {
		unsafe { key.write_ptr(&u8(&value), sizeof(T)) }
	}
}

fn page_switch_value_fields[T](mut key strings.Builder, command &T) bool {
	// Reflect scalar paint inputs so adding a new primitive cannot silently
	// omit it. Unknown payload types fail closed until explicitly supported.
	$for field in T.fields {
		$if field.typ is string || field.typ is bool || field.typ is f64 || field.typ is int || field.typ is u64 || field.typ is $enum || field.typ is [6]f64 || field.typ is []f64 || field.typ is BoxRadii {
			if field.name !in ['paint_box_index', 'paint_phase'] {
				page_switch_write(mut key, command.$(field.name))
			}
		} $else {
			if field.name !in ['srgb_color_data', 'force_dark_backdrop', 'glyph_run',
				'local_border_data', 'checkbox_theme_data', 'box_shadow_data', 'gradient', 'svg_data',
				'image_data', 'image_paintable', 'replaced_image_bitmap', 'canvas_bitmap',
				'canvas_paintable', 'video_bitmap', 'video_frame_source', 'video_paintable',
				'nested_viewport_commands', 'nested_viewport_paintable', 'text_clip_runs', 'clip_list',
				'recording_clip', 'visual_context_index', 'visual_layer_list', 'visual_layer_data', 'backdrop_filter_data',
				'mask_clip_data'] {
				return false
			}
		}
	}
	return true
}

// Unsupported resources are deliberately dirty, even if their URL is equal.
// This avoids retaining stale decoded images, video, SVG and font-face data.
fn page_switch_leaf_key(command &PaintCommand) ?string {
	if command.kind !in ['fill_rect', 'fill_rounded_rect', 'stroke_rounded_rect', 'fill_ellipse',
		'stroke_ellipse', 'paint_uniform_border', 'paint_rounded_border_top',
		'paint_rounded_border_right', 'paint_rounded_border_bottom', 'paint_rounded_border_left',
		'draw_line', 'fill_polygon', 'draw_text']
		|| command.blur != 0 || command.outer_shadow || command.underlays_next
		|| command.local_border_data != unsafe { nil }
		|| command.checkbox_theme_data != unsafe { nil }
		|| command.box_shadow_data != unsafe { nil }
		|| command.svg_data != unsafe { nil } || command.image_data != unsafe { nil }
		|| command.visual_layer_list != unsafe { nil }
		|| command.gradient != none || command.image_paintable != none
		|| command.replaced_image_bitmap != none || command.canvas_bitmap != none
		|| command.canvas_paintable != none || command.video_bitmap != none
		|| command.video_frame_source != none || command.video_paintable != none
		|| command.nested_viewport_paintable != none || command.visual_layer_data != none
		|| command.backdrop_filter_data != none || command.mask_clip_data != none
		|| (command.kind == 'draw_text' && command.glyph_run == none)
		|| command.text_clip_runs.len != 0 || command.nested_viewport_commands.len != 0 {
		return none
	}
	mut key := strings.new_builder(512)
	defer { key.free() }
	if !page_switch_value_fields(mut key, command) { return none }
	key.write_string(json2.encode(command.force_dark_backdrop))
	key.write_string(json2.encode(command.recording_clip))
	key.write_string(json2.encode(command.visual_context_index))
	page_switch_write(mut key, command.srgb_color_data != unsafe { nil })
	if command.srgb_color_data != unsafe { nil } {
		key.write_string(json2.encode(*command.srgb_color_data))
	}
	page_switch_write(mut key, command.clip_list != unsafe { nil })
	if command.clip_list != unsafe { nil } {
		page_switch_write(mut key, command.clip_list.items.len)
		for clip in command.clip_list.items {
			// Ordinary overflow and rounded rectangle clips own only geometry.
			// Mask/path clips can depend on resources outside this document.
			$for field in PaintClip.fields {
				if field.name !in ['rect', 'corner_radii', 'transform', 'is_path', 'is_svg_mask',
					'is_svg_content_mask', 'path_data', 'path_even_odd', 'path_components',
					'mask_operations', 'cache_key', 'scope_id', 'mask_luminance'] { return none }
			}
			if clip.is_path || clip.is_svg_mask || clip.is_svg_content_mask
				|| clip.path_data.len != 0 || clip.path_components.len != 0 || clip.mask_operations.len != 0 {
				return none
			}
			page_switch_write(mut key, clip.rect)
			page_switch_write(mut key, clip.corner_radii)
			page_switch_write(mut key, clip.transform)
		}
	}
	page_switch_write(mut key, command.glyph_run != none)
	if run := command.glyph_run {
		font := run.font_
		if font == unsafe { nil } || font.source_path != '' { return none }
		page_switch_write(mut key, run.glyphs_)
		page_switch_write(mut key, run.face_)
		page_switch_write(mut key, run.text_type_)
		page_switch_write(mut key, font.family)
		page_switch_write(mut key, font.point_size)
		page_switch_write(mut key, font.weight)
		page_switch_write(mut key, font.italic)
		page_switch_write(mut key, font.is_invisible)
		page_switch_write(mut key, font.font_rendering_policy)
		page_switch_write(mut key, font.synthesize_ascii_caps)
		if face := font.system_face() { key.write_string(face.replay_key()) }
	}
	result := sha256.sum(key).hex()
	return result
}

fn page_switch_outside(command &PaintCommand, x f64, y f64, width f64, height f64) bool {
	// Native controls and CSS borders contain packed paths. They remain dirty,
	// but must not invalidate unrelated header/sidebar tiles. Bézier ink stays
	// within its control hull; arcs use an enclosing disk after radius correction.
	// Accept only translation in the inner path matrix; arbitrary SVG keeps the
	// conservative whole-viewport fallback, including non-scaling strokes.
	if command.kind == 'draw_svg_path' && command.svg_data != unsafe { nil } {
		data := command.svg_data
		matrix := normalized_affine(data.path_transform)
		stride := compatibility_clip_path_segment_stride
		if data.non_scaling_stroke || data.svg_gradient_data != none
			|| data.fill_pattern != none || data.stroke_pattern != none
			|| data.path_data.len == 0 || data.path_data.len % stride != 0
			|| matrix[0] != 1 || matrix[1] != 0 || matrix[2] != 0 || matrix[3] != 1 {
			return false
		}
		mut left := math.inf(1)
		mut top := math.inf(1)
		mut right := math.inf(-1)
		mut bottom := math.inf(-1)
		mut current_x := f64(0)
		mut current_y := f64(0)
		mut start_x := f64(0)
		mut start_y := f64(0)
		if data.path_data[0] != 0 { return false }
		for offset := 0; offset < data.path_data.len; offset += stride {
			kind := data.path_data[offset]
			if kind == 5 { current_x = start_x; current_y = start_y; continue }
			if kind !in [f32(0), 1, 2, 3, 4] { return false }
			point_count := if kind == 3 { 3 } else if kind == 2 { 2 } else { 1 }
			for index in 0 .. point_count {
				px := f64(data.path_data[offset + 1 + index * 2])
				py := f64(data.path_data[offset + 2 + index * 2])
				if math.is_nan(px) || math.is_inf(px, 0) || math.is_nan(py) || math.is_inf(py, 0) {
					return false
				}
				left = math.min(left, px)
				top = math.min(top, py)
				right = math.max(right, px)
				bottom = math.max(bottom, py)
			}
			px := f64(data.path_data[offset + 1])
			py := f64(data.path_data[offset + 2])
			if kind == 4 {
				rx := math.abs(f64(data.path_data[offset + 7]))
				ry := math.abs(f64(data.path_data[offset + 8]))
				angle := f64(data.path_data[offset + 9])
				if math.is_nan(rx) || math.is_inf(rx, 0) || math.is_nan(ry) || math.is_inf(ry, 0)
					|| math.is_nan(angle) || math.is_inf(angle, 0) { return false }
				if rx > 0 && ry > 0 {
					dx := (current_x - px) / 2
					dy := (current_y - py) / 2
					u := (math.cos(angle) * dx + math.sin(angle) * dy) / rx
					v := (-math.sin(angle) * dx + math.cos(angle) * dy) / ry
					// Every point lies within two corrected maximum radii of
					// the starting point, for either sweep and large-arc flag.
					radius := 2 * math.max(rx, ry) * math.max(1, math.sqrt(u * u + v * v))
					left = math.min(left, current_x - radius)
					top = math.min(top, current_y - radius)
					right = math.max(right, current_x + radius)
					bottom = math.max(bottom, current_y + radius)
				}
			}
			current_x = px
			current_y = py
			if kind == 0 { start_x = px; start_y = py }
		}
		if !(right >= left && bottom >= top) || math.is_nan(data.stroke_miterlimit)
			|| math.is_inf(data.stroke_miterlimit, 0) || math.is_nan(command.stroke_width)
			|| math.is_inf(command.stroke_width, 0) { return false }
		// The full stroke width times the miter limit also encloses square/round
		// caps and the native hairline fringe. The shared helper adds AA guards.
		outset := math.max(1, math.abs(command.stroke_width) * math.max(1, math.abs(data.stroke_miterlimit)))
		return paint_leaf_is_outside_canvas(PaintCommand{...command, kind: 'fill_rect',
			x: left + matrix[4] - outset, y: top + matrix[5] - outset, width: right - left + outset * 2,
			height: bottom - top + outset * 2}, x, y, width, height)
	}
	if rounded_single_border_mode(command.kind) != 0 && command.local_border_data == unsafe { nil } {
		// Single-side borders are clipped to their complete outer rectangle.
		return paint_leaf_is_outside_canvas(PaintCommand{...command, kind: 'fill_rect'}, x, y, width, height)
	}
	if command.kind == 'paint_uniform_border' && command.local_border_data == unsafe { nil } {
		return paint_leaf_is_outside_canvas(PaintCommand{...command, kind: 'stroke_rounded_rect'}, x, y, width, height)
	}
	return paint_leaf_is_outside_canvas(command, x, y, width, height)
}

pub fn page_switch_tiles(commands []PaintCommand, width int, height int) PageSwitchTiles {
	if width <= 0 || height <= 0 || width > 8192 || height > 8192 { return PageSwitchTiles{} }
	columns := (width + page_switch_tile_size - 1) / page_switch_tile_size
	rows := (height + page_switch_tile_size - 1) / page_switch_tile_size
	mut builders := []strings.Builder{len: columns * rows, init: strings.new_builder(256)}
	mut dirty := []bool{len: builders.len}
	mut unsupported := map[string]int{}
	mut in_group := false
	for command in commands {
		if command.scrollbar_axis != '' { continue }
		// A Skia control group is always repainted where its children paint.
		// Its boundaries have no independent pixels or safe standalone bounds.
		if command.kind == 'begin_skia_command_group' { in_group = true; continue }
		if command.kind == 'end_skia_command_group' { in_group = false; continue }
		if page_switch_outside(command, 0, 0, width, height) { continue }
		leaf := if in_group { ?string(none) } else { page_switch_leaf_key(command) }
		if leaf == none && os.getenv('VOX_PAGE_SWITCH_DIAGNOSTICS') == '1' {
			unsupported[command.kind]++
			if !page_switch_outside(command, -width * 2, -height * 2, width, height) {
				eprintln('VOX_PAGE_SWITCH_UNBOUNDED kind=${command.kind} rect=${command.x},${command.y},${command.width},${command.height} underlay=${command.underlays_next} local_border=${command.local_border_data != unsafe { nil }} svg=${command.svg_data != unsafe { nil }}')
			}
		}
		for index in 0 .. builders.len {
			if dirty[index] { continue }
			x := (index % columns) * page_switch_tile_size
			y := (index / columns) * page_switch_tile_size
			if page_switch_outside(command, -x, -y,
				math.min(page_switch_tile_size, width - x), math.min(page_switch_tile_size, height - y)) {
				continue
			}
			if value := leaf { builders[index].write_string(value) } else { dirty[index] = true }
		}
	}
	mut keys := []string{len: builders.len}
	for index, mut builder in builders {
		if !dirty[index] { keys[index] = sha256.hexhash(builder.str()) }
		builder.free()
	}
	if os.getenv('VOX_PAGE_SWITCH_DIAGNOSTICS') == '1' {
		eprintln('VOX_PAGE_SWITCH_TILES known=${keys.filter(it != "").len} total=${keys.len} unsupported=${unsupported}')
	}
	return PageSwitchTiles{width, height, keys}
}

// Dirty rectangles are viewport-relative, top-down CSS pixels. A missing key
// is always dirty. Changed/removed commands invalidate every intersected tile.
pub fn (before PageSwitchTiles) damage(after PageSwitchTiles) []LayoutRect {
	if before.width != after.width || before.height != after.height
		|| before.keys.len == 0 || before.keys.len != after.keys.len {
		return [LayoutRect{0, 0, after.width, after.height}]
	}
	columns := (after.width + page_switch_tile_size - 1) / page_switch_tile_size
	mut rects := []LayoutRect{}
	for index, key in after.keys {
		if key != '' && key == before.keys[index] { continue }
		x := (index % columns) * page_switch_tile_size
		y := (index / columns) * page_switch_tile_size
		rects << LayoutRect{x, y, math.min(page_switch_tile_size, after.width - x), math.min(page_switch_tile_size, after.height - y)}
	}
	return rects
}
