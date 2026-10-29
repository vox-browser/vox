module platform

import math

fn test_system_ui_faces_retain_css_weight_between_named_masters() {
	$if macos {
		for weight in [100, 200, 300, 500, 550, 600, 650, 700, 800, 900] {
			for italic in [false, true] {
				font := &Font{
					family:                'SystemUi'
					point_size:            12
					weight:                weight
					italic:                italic
					font_rendering_policy: .chromium
				}
				face := font.system_face() or { panic('missing UI face') }
				assert FontVariationAxis{ tag: 0x77676874, value: f32(weight) } in face.variations
				assert face.italic == italic
			}
		}
	}
}

fn test_system_ui_star_advances_match_brave_at_each_requested_weight() {
	$if macos {
		// Brave 156.1.98.60, 12px system-ui, each star in its own inline block.
		expected := [11.671875, 11.84375, 12.015625, 12.1875, 12.3125, 12.375, 12.421875, 12.484375,
			12.546875, 12.65625, 12.765625]
		for index, weight in [100, 200, 300, 400, 500, 550, 600, 650, 700, 800, 900] {
			font := &Font{
				family:                'SystemUi'
				point_size:            12
				weight:                weight
				font_rendering_policy: .chromium
			}
			width := shaped_text_width(0, 0, '★', font, .ltr)
			assert math.ceil(f64(width) * 64) / 64 == expected[index]
		}
	}
}
