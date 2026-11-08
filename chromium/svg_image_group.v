module main

import css
import layout
import painting

#include "@VMODROOT/native/include/native_graphite_bridge.h"

@[typedef]
struct C.VoxGraphitePath {
	matrix             [9]f32
	segments           &f32
	segment_count      int
	even_odd           int
	red                u8
	green              u8
	blue               u8
	alpha              u8
	stroke             int
	line_cap           int
	line_join          int
	non_scaling_stroke int
	stroke_width       f32
	miter_limit        f32
	gradient           int
	tile_mode          int
	linear_color_space int
	stop_count         int
	gradient_points    [6]f32
	gradient_matrix    [9]f32
	opacity            f32
	stops              &f32
	has_float_alpha    int
	has_clip           int
	clip               [12]f32
	has_ancestor_clip  int
	ancestor_clip      [12]f32
	has_float_color    int
	float_color        [4]f32
}

fn C.native_draw_svg_path_batch(&C.VoxGraphitePath, int, &f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, &f32) int

// Retain rectangular clipPath scopes in the image's local coordinates. Mapping
// their paths into the page before creating a recording loses viewBox precision
// and can resolve coincident path/clip coverage more than once.
fn chromium_svg_image_path_clip(path &layout.PaintCommand,
	masks []painting.Rect) ?C.VoxGraphitePath {
	if masks.len > 0 || (path.clip_list != unsafe { nil } && path.clip_list.items.len > 0)
		|| path.has_clip {
		if masks.len > 0 {
			color := path.retained_svg_fill_color() or { css.parse_color_string(path.color) or { return none } }
			if path.svg_data == unsafe { nil } || path.svg_data.fill_opacity != 1
				|| chromium_svg_solid_paint_alpha(path, false, color.a) != 1 {
				return none
			}
		}
		return chromium_svg_background_path_clips(path, masks)
	}
	return C.VoxGraphitePath{}
}

fn chromium_svg_image_mask_boundary(command &layout.PaintCommand) bool {
	return command.opacity == 1 && command.group_opacity == 1 && !command.has_clip
		&& command.clip_outs.len == 0 && command.recording_clip == none
		&& normalized_paint_transform(command.transform) == [f64(1), 0, 0, 1, 0, 0]!
}

// Solid images, including balanced rectangular clipPaths, can share one GPU
// recording. Effects and nonrectangular masks retain their ordinary replay.
fn chromium_svg_image_can_share_recording(command layout.PaintCommand) bool {
	if command.opacity != 1 || command.group_opacity != 1 || command.nested_viewport_commands.len == 0
		|| command.nested_viewport_commands.len > 32768 {
		return false
	}
	mut masks := []painting.Rect{}
	mut boundaries := []layout.PaintClip{}
	mut count := 0
	for path in command.nested_viewport_commands {
		if path.kind == 'begin_svg_mask_layer' {
			if !chromium_svg_image_mask_boundary(&path) { return false }
			matrix := normalized_paint_transform(command.transform)
			if matrix[0] != 1 || matrix[1] != 0 || matrix[2] != 0 || matrix[3] != 1 { return false }
			clip := path.mask_clip()
			if !clip.is_svg_mask || clip.is_svg_content_mask { return false }
			masks << svg_background_rectangular_clip(clip) or { return false }
			boundaries << clip
			continue
		}
		if path.kind == 'end_svg_mask_layer' {
			if boundaries.len == 0 || !chromium_svg_image_mask_boundary(&path) { return false }
			clip := path.mask_clip()
			first := boundaries.last()
			rect := svg_background_rectangular_clip(clip) or { return false }
			if !clip.is_svg_mask || clip.is_svg_content_mask || clip.cache_key != first.cache_key
				|| clip.scope_id != first.scope_id || clip.rect != first.rect
				|| clip.transform != first.transform
				|| rect != masks.last() {
				return false
			}
			boundaries.delete_last()
			masks.delete_last()
			continue
		}
		if path.kind != 'draw_svg_path' || path.opacity != 1 || path.group_opacity != 1
			|| path.clip_outs.len > 0 || path.recording_clip != none {
			return false
		}
		// Read the payload directly: an accessor call on the loop's copy of the
		// command makes current V move that copy to the heap.
		if path.svg_data == unsafe { nil } { return false }
		svg := path.svg_data
		if svg.path_data.len == 0 || svg.stroke_dasharray.len > 0 || svg.svg_gradient_data != none
			|| svg.fill_pattern != none || svg.stroke_pattern != none {
			return false
		}
		_ := chromium_svg_image_path_clip(&path, masks) or { return false }
		count++
	}
	return boundaries.len == 0 && count > 0
}

fn (mut app BrowserApp) draw_chromium_svg_image_group(command layout.PaintCommand,
	result painting.NavigableContainerViewportPaintResult, page_x f32, page_y f32, scroll_y f64) bool {
	$if macos {
		if app.document == unsafe { nil } || app.document.font_rendering_policy() != .chromium
			|| !chromium_svg_image_can_share_recording(command) {
			return false
		}
		mut paths := []C.VoxGraphitePath{cap: command.nested_viewport_commands.len * 2}
		mut masks := []painting.Rect{}
		for nested in command.nested_viewport_commands {
			if nested.kind == 'begin_svg_mask_layer' {
				masks << svg_background_rectangular_clip(nested.mask_clip()) or { return false }
				continue
			}
			if nested.kind == 'end_svg_mask_layer' {
				masks.delete_last()
				continue
			}
			// Keep the SVG recording local until the native raster origin is
			// known. Casting a page translation to float first loses tiny
			// viewBox alignment offsets, even after that translation is removed.
			path := nested
			svg := path.svg()
			clip := chromium_svg_image_path_clip(&path, masks) or { return false }
			matrix := multiply_paint_transforms(path.transform, svg.path_transform)
			order := if svg.stroke_first { [1, 0] } else { [0, 1] }
			for part in order {
				if part == 0 && path.color == '' {
					continue
				}
				if part == 1 && (path.stroke_color == '' || path.stroke_width <= 0) {
					continue
				}
				color := if part == 0 {
					app.paint_colors.color_with_retained(path.color, 1,
						path.retained_svg_fill_color())
				} else {
					app.paint_colors.color_with_retained(path.stroke_color, 1,
						path.retained_svg_stroke_color())
				}
				precise := path.retained_svg_solid_components(part != 0)
				components := precise or {
					[f64(color.r) / 255, f64(color.g) / 255, f64(color.b) / 255, f64(color.a) / 255]!
				}
				paths << C.VoxGraphitePath{
					matrix:             [f32(matrix[0]), f32(matrix[2]), f32(matrix[4]),
						f32(matrix[1]), f32(matrix[3]), f32(matrix[5]), f32(0), f32(0), f32(1)]!
					segments:           svg.path_data.data
					segment_count:      svg.path_data.len / layout.compatibility_clip_path_segment_stride
					even_odd:           int(svg.fill_even_odd)
					red:                color.r
					green:              color.g
					blue:               color.b
					alpha:              color.a
					stroke:             part
					line_cap:           svg.stroke_linecap
					line_join:          svg.stroke_linejoin
					non_scaling_stroke: int(svg.non_scaling_stroke)
					stroke_width:       f32(path.stroke_width * if svg.non_scaling_stroke {
						app.document.layout_coordinate_scale()
					} else {
						1.0
					})
					miter_limit:        f32(svg.stroke_miterlimit)
					has_float_alpha:    1
					has_float_color:    int(precise != none)
					float_color:        [f32(components[0]), f32(components[1]), f32(components[2]),
						f32(components[3])]!
					opacity:            f32(chromium_svg_solid_paint_alpha(&path, part != 0, color.a) *
						if part == 0 { svg.fill_opacity } else { svg.stroke_opacity })
					has_clip:           clip.has_clip
					clip:               clip.clip
				}
			}
		}
		matrix := multiply_paint_transforms(command.transform,
			[f64(1), 0, 0, 1, f64(result.nested_rect.x), f64(result.nested_rect.y)]!)
		outer := [f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]),
			f32(matrix[5])]!
		return C.native_draw_svg_path_batch(paths.data, paths.len, &outer[0],
			f32(result.clip_rect.x - result.nested_rect.x), f32(result.clip_rect.y - result.nested_rect.y), f32(result.clip_rect.width),
			f32(result.clip_rect.height), page_x, page_y, f32(scroll_y), f32(app.ctx.width),
			f32(app.ctx.height), unsafe { nil }) != 0
	}
	return false
}
