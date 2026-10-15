module layout

import math
import platform

fn test_portable_shadow_replays_transformed_radii_clip_and_source_bounds() {
	angle := math.pi / 4
	cosine := math.cos(angle)
	sine := math.sin(angle)
	negative_sine := -sine
	command := PaintCommand{
		kind: 'paint_outer_box_shadow'
		x: 20
		y: 20
		width: 20
		height: 12
		blur: 4
		color: 'blue'
		corner_radii: BoxRadii{ top_left: CornerRadius{4, 2}, top_right: CornerRadius{2, 4} }
		box_shadow_data: &PaintBoxShadowData{
			content_rect: LayoutRect{20, 20, 20, 12}
			content_radii: BoxRadii{ top_left: CornerRadius{4, 2}, top_right: CornerRadius{2, 4} }
		}
		transform: [cosine, sine, negative_sine, cosine, 40, 0]!
	}
	bitmap := rasterize_portable_shadow(command, 2)!
	assert bitmap.width > 60
	assert bitmap.height > 60
	assert bitmap.pixels.filter(it > 0).len > 100
	mut translucent := 0
	for index := 3; index < bitmap.pixels.len; index += 4 {
		if bitmap.pixels[index] > 0 && bitmap.pixels[index] < 255 { translucent++ }
	}
	assert translucent > 100
}

fn test_portable_text_shadow_keeps_glyph_slices_and_baseline_translation() {
	font := &platform.Font{ family: 'sans-serif', point_size: 20 }
	run := platform.shape_text(0, 0, 'AB', font, .ltr)
	bitmap := rasterize_portable_shadow(PaintCommand{
		kind: 'draw_text_shadow'
		x: 30
		y: 20
		width: 40
		height: 30
		blur: 4
		color: 'rgba(0,0,255,0.5)'
		glyph_run: run.slice(1, 1)
		glyph_translation_x: 30
		glyph_translation_y: 42
	}, 1)!
	assert bitmap.x == 22
	assert bitmap.y == 12
	assert bitmap.width == 56
	assert bitmap.height == 46
	mut largest := u8(0)
	for index := 3; index < bitmap.pixels.len; index += 4 {
		largest = u8(math.max(largest, bitmap.pixels[index]))
	}
	assert largest > 0 && largest <= 128
}
