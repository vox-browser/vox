module main

import layout

fn test_rectangle_screen_corners_retain_rotation_order_and_scroll() {
	command := layout.PaintCommand{
		x: 2
		y: 3
		width: 5
		height: 7
		transform: [f64(0), 1, -1, 0, 10, 20]!
	}
	points := transformed_rect_points(command, 1.25, 2.5, 0.75)
	assert points == [f32(8.25), 23.75, 8.25, 28.75, 1.25, 28.75, 1.25, 23.75]!
	// Portable polygon replay borrows these same four corners. In particular,
	// rotating the rectangle must not replace its winding with its AABB.
	borrowed := borrowed_rectangle_screen_points(&points)
	assert borrowed.len == 8
	assert unsafe { borrowed.data == &points[0] }
	assert borrowed.flags.has(.nofree)
	assert borrowed.flags.has(.nogrow)
	assert borrowed.flags.has(.noshrink)
	assert borrowed == [f32(8.25), 23.75, 8.25, 28.75, 1.25, 28.75, 1.25, 23.75]
	assert sizeof(points) == 8 * sizeof(f32)
}

fn test_rectangle_screen_corners_keep_the_existing_float_rounding() {
	transforms := [
		[6]f64{},
		[f64(1), 0, 0, 1, 0, 0]!,
		[f64(-2), 0.5, 1.25, 3, -4.5, 7.25]!,
		[f64(0), -1, 1, 0, -12.25, 6.125]!,
		[f64(0.25), 0, 0, 0.75, 16777216.5, -16777216.5]!,
	]
	rectangles := [
		layout.LayoutRect{2, 3, 5, 7},
		layout.LayoutRect{-17.125, -3.25, 0, 8.5},
		layout.LayoutRect{16777216.5, -16777216.5, 3.25, -2.75},
	]
	for transform in transforms {
		for rect in rectangles {
			command := layout.PaintCommand{
				x: rect.x
				y: rect.y
				width: rect.width
				height: rect.height
				transform: transform
			}
			for scroll in [f64(0), 0.125, 16777216.25] {
				actual := transformed_rect_points(command, 1.25, -2.5, scroll)
				// Compare against the previous array-building implementation. The
				// cast before the page offset deliberately rounds at f32 precision.
				mut expected := []f32{cap: 8}
				for point in [[rect.x, rect.y], [rect.x + rect.width, rect.y],
					[rect.x + rect.width, rect.y + rect.height], [rect.x, rect.y + rect.height]] {
					mapped_x, mapped_y := map_paint_point(transform, point[0], point[1])
					expected << f32(1.25) + f32(mapped_x)
					expected << f32(-2.5) + f32(mapped_y - scroll)
				}
				assert actual[..] == expected
			}
		}
	}
}

fn test_rectangle_screen_corner_snapshots_are_independent_of_later_commands() {
	mut command := layout.PaintCommand{x: -4, y: 6, width: 10, height: 8}
	before := transformed_rect_points(command, 0, 0, 1)
	command.x = 100
	command.transform = [f64(2), 0, 0, 3, 7, 9]!
	after := transformed_rect_points(command, 0, 0, 1)
	gc_collect()
	assert before == [f32(-4), 5, 6, 5, 6, 13, -4, 13]!
	assert after == [f32(207), 26, 227, 26, 227, 50, 207, 50]!
	// Arbitrary line/polygon points still use the common mapping helper.
	x, y := paint_screen_point(command, -3.5, 7.25, 0.5, -0.25, 1.5)
	assert x == f32(0.5)
	assert y == f32(29)
}
