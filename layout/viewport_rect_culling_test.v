module layout

import math

fn test_direct_viewport_rect_culling_matches_native_leaf_precision_and_fringe() {
	transforms := [
		[6]f64{},
		[f64(1), 0, 0, 1, 0, 0]!,
		[f64(1), 0, 0, 1, .25, -1000.75]!,
		[f64(2), .125, -.25, -1, 20, 15]!,
		[f64(0), 1, -1, 0, 50, 50]!,
		[f64(1), 0, 0, 1, -1_000_001, 0]!,
		[f64(1_000_001), 0, 0, 1, 0, 0]!,
		[f64(1), math.nan(), 0, 1, 0, 0]!,
		[f64(1), 0, 0, 1, math.inf(1), 0]!,
	]
	for transform in transforms {
		for x in [f64(-1_000_001), -1000, -24, -3.001, -.25, 0, 20, 323.001, 1_000_001, math.nan(), math.inf(1)] {
			for y in [f64(-1000), -24, -3, .125, 103, 1000] {
				for extent in [f64(-25), 0, .25, 20, 1_000_001] {
					rect := LayoutRect{x, y, extent, extent + .125}
					command := PaintCommand{kind: 'fill_rect', x: rect.x, y: rect.y,
						width: rect.width, height: rect.height, transform: transform}
					for viewport in [LayoutRect{0, 0, 320, 100}, LayoutRect{0, 0, 0, 100},
						LayoutRect{0, 0, math.nan(), 100}, LayoutRect{0, 0, 320, 1_000_001}] {
						expected := paint_leaf_is_outside_canvas(command, 0, 0, viewport.width, viewport.height)
						assert viewport_rect_outside_native_canvas(rect, transform, viewport.width, viewport.height) == expected,
							'x=${x}, y=${y}, extent=${extent}, transform=${transform}'
					}
				}
			}
		}
	}
}
