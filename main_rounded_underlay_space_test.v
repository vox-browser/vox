module main

import html
import layout
import math
import platform

fn test_transformed_modal_background_keeps_its_position_in_the_border_pass() {
	for density in [f64(1), 2] {
		for transform in ['scale(1)', 'translate(.25px, .5px)', 'scale(.95)', 'rotate(12deg)'] {
			mut document := html.parse_document('<!doctype html><style>
				body{margin:0}.outer{position:absolute;inset:0;display:flex;align-items:center;justify-content:center}
				.modal{box-sizing:border-box;position:relative;width:400px;height:431.125px;
				padding:8px 0 16px;border:1px solid rgba(170,171,175,.12);border-radius:12px;
				background:rgb(35 35 40);transform:${transform}}
				</style><div class="outer"><div class="modal"></div></div>')
			defer { document.finalize() }
			document.set_font_rendering_policy(.chromium)
			document.set_layout_coordinate_scale(density)
			_ = layout.layout_document_typed_in_viewport(document, 1280, 788)
			commands := layout.display_list_commands(document.record_display_list() or { panic('paint') })
			backgrounds := commands.filter(it.kind == 'fill_rect' && it.color == 'rgb(35 35 40)')
			borders := commands.filter(it.kind == 'paint_uniform_border')
			assert backgrounds.len == 1 && borders.len == 1
			background := backgrounds[0]
			border := borders[0]
			assert background.underlays_next
			assert background.transform != border.transform
			assert rounded_underlay_offset(&background, &border).valid
			rect := rounded_underlay_rect(&background, &border, f32(background.radius))
			from := normalized_paint_transform(background.transform)
			to := normalized_paint_transform(border.transform)
			// Independent projections must reach the same device point at all
			// four corners, including a rotated/shared non-identity basis.
			for corner in [[f64(0), 0], [background.width, 0],
				[f64(0), background.height], [background.width, background.height]] {
				x := background.x + corner[0]
				y := background.y + corner[1]
				rx := f64(rect[0]) + corner[0]
				ry := f64(rect[1]) + corner[1]
				assert math.abs(from[0] * x + from[2] * y + from[4]
					- (to[0] * rx + to[2] * ry + to[4])) < 0.0001
				assert math.abs(from[1] * x + from[3] * y + from[5]
					- (to[1] * rx + to[3] * ry + to[5])) < 0.0001
			}
			if transform == 'scale(1)' {
				assert rect[0] > 400 * density && rect[1] > 150 * density
				assert chromium_uniform_border_uses_clip_layer(&border, &background)
			}
		}
	}
}

fn test_rounded_underlay_rejects_incompatible_or_invalid_coordinate_spaces() {
	background := layout.PaintCommand{transform: [f64(1), 0, 0, 1, 40, 70]!}
	for matrix in [[f64(2), 0, 0, 1, 0, 0]!, [f64(1), 0.2, 0, 1, 0, 0]!,
		[f64(1), 0, 0, 1, math.inf(1), 0]!, [f64(1), 0, 0, 1, math.nan(), 0]!] {
		assert !rounded_underlay_offset(&background, &layout.PaintCommand{transform: matrix}).valid
	}
	assert !rounded_underlay_offset(&layout.PaintCommand{transform: [f64(0), 0, 0, 1, 4, 0]!},
		&layout.PaintCommand{transform: [f64(0), 0, 0, 1, 0, 0]!}).valid
	clipped := layout.PaintCommand{...background, clip_outs: [f64(1), 2, 3, 4]}
	assert !rounded_underlay_offset(&clipped, &layout.PaintCommand{}).valid
	assert rounded_underlay_offset(&clipped, &clipped).valid
}

fn test_rounded_underlay_projection_does_not_retain_per_draw_storage() {
	background := layout.PaintCommand{x: -1, y: -9.5, width: 400, height: 432,
		transform: [f64(1), 0, 0, 1, 441, 188]!}
	consumer := layout.PaintCommand{}
	before := platform.thread_arena_usage().used
	mut sum := f64(0)
	for _ in 0 .. 256 {
		rect := rounded_underlay_rect(&background, &consumer, 12)
		sum += rect[0]
	}
	assert sum == 440 * 256
	$if prealloc { assert platform.thread_arena_usage().used - before < 4096 }
}
