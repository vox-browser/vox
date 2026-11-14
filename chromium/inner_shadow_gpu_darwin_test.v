// vtest build: macos
module main

import html
import layout
import math
import os

fn inset_shadow_test_command(dx f64, dy f64, spread f64) layout.PaintCommand {
	r := layout.BoxRadii{
		top_left:     layout.CornerRadius{5, 5}
		top_right:    layout.CornerRadius{5, 5}
		bottom_left:  layout.CornerRadius{5, 5}
		bottom_right: layout.CornerRadius{5, 5}
	}
	return layout.PaintCommand{
		kind:            'paint_inner_box_shadow'
		color:           '#1f23280a'
		box_shadow_data: &layout.PaintBoxShadowData{
			content_rect:  layout.LayoutRect{360, 262, 202, 30}
			content_radii: r
			clip_radii:    r
			inner_rect:    layout.LayoutRect{360 + spread + dx, 262 + spread + dy, 202 - 2 * spread, 30 - 2 * spread}
			inner_radii:   r
		}
	}
}

fn test_unblurred_inset_caster_covers_clip_and_offset_with_spread() {
	for offsets, expected in {
		'0,1,0':   [f32(360), 262, 202, 31, 0, 0, 0, 0, 0, 0, 0, 0]!
		'-3,2,2':  [f32(357), 262, 205, 32, 0, 0, 0, 0, 0, 0, 0, 0]!
		'4,-3,-2': [f32(358), 257, 210, 37, 0, 0, 0, 0, 0, 0, 0, 0]!
	} {
		parts := offsets.split(',').map(it.f64())
		c := inset_shadow_test_command(parts[0], parts[1], parts[2])
		s := unblurred_inner_shadow_shape(c) or { panic('eligible inset') }
		assert s.rect == expected
		assert s.fill == 14 && s.force_msaa == 0 && s.has_contour_reference == 1
		assert s.underlay_rect[0] == f32(c.box_shadow().inner_rect.x)
		assert s.contour_reference[0] == 360 && s.contour_reference[1] == 262
	}
}

fn test_unblurred_inset_unsafe_replay_keeps_fallback() {
	c := inset_shadow_test_command(0, 1, 0)
	b := c.box_shadow()
	for altered in [
		layout.PaintCommand{ ...c, kind: 'paint_outer_box_shadow' },
		layout.PaintCommand{ ...c, blur: 1 },
		layout.PaintCommand{ ...c, box_shadow_data: unsafe { nil } },
		layout.PaintCommand{ ...c, has_clip: true },
		layout.PaintCommand{ ...c, clip_list: &layout.PaintClipList{} },
		layout.PaintCommand{ ...c, recording_clip: layout.LayoutRect{0, 0, 10, 10} },
		layout.PaintCommand{ ...c, clip_outs: [f64(0), 0, 10, 10] },
		layout.PaintCommand{
			...c
			box_shadow_data: &layout.PaintBoxShadowData{
				...b
				clip_radii: layout.BoxRadii{}
			}
		},
		layout.PaintCommand{
			...c
			box_shadow_data: &layout.PaintBoxShadowData{
				...b
				inner_rect: layout.LayoutRect{360, 263, 200, 30}
			}
		},
		layout.PaintCommand{
			...c
			box_shadow_data: &layout.PaintBoxShadowData{
				...b
				content_rect: layout.LayoutRect{math.nan(), 262, 202, 30}
			}
		},
	] {
		assert unblurred_inner_shadow_shape(altered) == none
	}
}

fn test_unblurred_inset_keeps_analytic_tile_coverage_without_svg() {
	c := inset_shadow_test_command(0, 1, 0)
	assert chromium_msaa_tiles([c], 1, 256).len == 0
	mut document := html.parse_document(os.read_file('${@VMODROOT}/Tests/Browser/Brave/input/unblurred-inset-shadow.html')!)
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout.layout_document_typed_in_viewport(document, 1024, 768)
	commands := root.paint_commands()
	mut shadows := 0
	for command in commands {
		assert command.kind != 'draw_svg_path'
		if command.kind != 'paint_inner_box_shadow' { continue }
		assert unblurred_inner_shadow_shape(command) != none
		shadows++
	}
	assert shadows == 3
	assert chromium_msaa_tiles(commands, 1, 256).len == 0
}
