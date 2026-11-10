// DisplayListPlayerSkia.cpp shadow replay for the Sokol presentation backend.
// The raster surface is only a backend transport; command geometry stays in
// the retained source coordinate system, including its visual-context clips.
module layout

import css
import math
import platform
import cpuraster

pub struct PortableShadowBitmap {
pub:
	x f32
	y f32
	width int
	height int
	pixels []u8
}

fn shadow_rect(x f64, y f64, width f64, height f64, radii BoxRadii) cpuraster.ShadowRect {
	return cpuraster.ShadowRect{
		rect: [f32(x), f32(y), f32(width), f32(height)]!
		radii: [f32(radii.top_left.x), f32(radii.top_left.y), f32(radii.top_right.x), f32(radii.top_right.y), f32(radii.bottom_right.x), f32(radii.bottom_right.y), f32(radii.bottom_left.x), f32(radii.bottom_left.y)]!
	}
}

fn portable_shadow_transform(input [6]f64, pixel_scale f64, origin_x f64, origin_y f64) [6]f32 {
	matrix := if input == [6]f64{} { [f64(1), 0, 0, 1, 0, 0]! } else { input }
	return [f32(matrix[0] * pixel_scale), f32(matrix[1] * pixel_scale), f32(matrix[2] * pixel_scale), f32(matrix[3] * pixel_scale), f32(matrix[4] * pixel_scale - origin_x), f32(matrix[5] * pixel_scale - origin_y)]!
}

pub fn rasterize_portable_shadow(command PaintCommand, pixel_scale f64) !PortableShadowBitmap {
	if command.kind !in ['paint_outer_box_shadow', 'paint_inner_box_shadow', 'draw_text_shadow'] {
		return error('Unsupported shadow command')
	}
	geometry := command.box_shadow()
	matrix := if command.transform == [6]f64{} { [f64(1), 0, 0, 1, 0, 0]! } else { command.transform }
	// PaintOuterBoxShadow/PaintTextShadow::bounding_rect() inflate by twice
	// the blur radius. Inner shadows are bounded by their content clip.
	mut bounds_x := command.x
	mut bounds_y := command.y
	mut bounds_width := command.width
	mut bounds_height := command.height
	if command.kind == 'paint_inner_box_shadow' {
		bounds_x = geometry.content_rect.x
		bounds_y = geometry.content_rect.y
		bounds_width = geometry.content_rect.width
		bounds_height = geometry.content_rect.height
	} else {
		bounds_x -= command.blur * 2
		bounds_y -= command.blur * 2
		bounds_width += command.blur * 4
		bounds_height += command.blur * 4
	}
	mut left := math.inf(1)
	mut top := math.inf(1)
	mut right := math.inf(-1)
	mut bottom := math.inf(-1)
	for point in [[bounds_x, bounds_y]!, [bounds_x + bounds_width, bounds_y]!, [bounds_x + bounds_width, bounds_y + bounds_height]!, [bounds_x, bounds_y + bounds_height]!] {
		x := (matrix[0] * point[0] + matrix[2] * point[1] + matrix[4]) * pixel_scale
		y := (matrix[1] * point[0] + matrix[3] * point[1] + matrix[5]) * pixel_scale
		left = math.min(left, x)
		top = math.min(top, y)
		right = math.max(right, x)
		bottom = math.max(bottom, y)
	}
	left = math.floor(left)
	top = math.floor(top)
	right = math.ceil(right)
	bottom = math.ceil(bottom)
	width := int(right - left)
	height := int(bottom - top)
	if width <= 0 || height <= 0 { return error('Empty shadow bounds') }
	color := css.parse_color_string(command.color) or { return error('Invalid shadow color') }
	alpha := u32(math.max(f64(0), math.min(f64(255), math.floor(f64(color.a) * command.opacity + .5))))
	content := shadow_rect(geometry.content_rect.x, geometry.content_rect.y, geometry.content_rect.width, geometry.content_rect.height, geometry.content_radii)
	mut clips := []cpuraster.ShadowClip{}
	if command.clip_list != unsafe { nil } {
		for clip in command.clip_list.items {
			if clip.is_svg_mask || clip.is_svg_content_mask { continue }
			clips << cpuraster.ShadowClip{
				shape: shadow_rect(clip.rect.x, clip.rect.y, clip.rect.width, clip.rect.height, clip.corner_radii)
				transform: portable_shadow_transform(clip.transform, pixel_scale, left, top)
				path: cpuraster.PackedPath{ segments: clip.path_data, even_odd: clip.path_even_odd }
				is_path: clip.is_path
			}
		}
	}
	if clip := command.recording_clip {
		clips << cpuraster.ShadowClip{
			shape: shadow_rect(clip.x, clip.y, clip.width, clip.height, BoxRadii{})
			transform: portable_shadow_transform(command.transform, pixel_scale, left, top)
		}
	}
	mut font_path := ''
	mut face_index := 0
	mut font_size := f32(0)
	mut glyphs := []u16{}
	mut positions := []f32{}
	if command.kind == 'draw_text_shadow' {
		run := command.glyph_run or { return error('Text shadow is missing its retained glyph run') }
		if run.font().is_invisible { return PortableShadowBitmap{ width: width, height: height, pixels: []u8{len: width * height * 4} } }
		font_path = if run.face() == .emoji {
			platform.emoji_font_path() or { return error('Emoji face unavailable') }
		} else {
			run.font().font_path() or { return error('Text shadow face unavailable') }
		}
		face_index = run.font().face_index()
		font_size = run.font().point_size
		glyphs = run.glyph_indices()
		positions = run.glyph_positions().map(f32(it))
	}
	native := cpuraster.ShadowCommand{
		kind: if command.kind == 'paint_outer_box_shadow' { 0 } else if command.kind == 'paint_inner_box_shadow' { 1 } else { 2 }
		color: (alpha << 24) | (u32(color.r) << 16) | (u32(color.g) << 8) | u32(color.b)
		blur: f32(command.blur)
		transform: portable_shadow_transform(command.transform, pixel_scale, left, top)
		content: content
		// Inner source uses content_corner_radii on the outer rectangle.
		outer: shadow_rect(command.x, command.y, command.width, command.height, if command.kind == 'paint_inner_box_shadow' { geometry.content_radii } else { command.corner_radii })
		inner: shadow_rect(geometry.inner_rect.x, geometry.inner_rect.y, geometry.inner_rect.width, geometry.inner_rect.height, geometry.inner_radii)
		clips: clips
		font_path: font_path
		face_index: face_index
		font_size: font_size
		glyphs: glyphs
		positions: positions
		translation: [f32(command.glyph_translation_x), f32(command.glyph_translation_y)]!
		font_smoothing: int(command.font_smoothing)
	}
	return PortableShadowBitmap{
		x: f32(left / pixel_scale)
		y: f32(top / pixel_scale)
		width: width
		height: height
		pixels: cpuraster.rasterize_shadow(width, height, native)!
	}
}
