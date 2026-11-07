module main

import painting

struct ChromiumBackgroundLocalOrigin {
	destination_x f32
	destination_y f32
	clip_x        f32
	clip_y        f32
	transform_e   f32
	transform_f   f32
}

// Blink records a background subset at a local origin, with its location on
// the canvas. Keeping large destination coordinates in the image rectangle
// instead changes the GPU's texture-coordinate rounding.
fn chromium_background_local_origin(destination painting.Rect, source painting.Rect,
	clip painting.Rect, matrix [6]f64, natural_width int, natural_height int,
	independent_raster bool) ChromiumBackgroundLocalOrigin {
	x := f32(destination.x)
	y := f32(destination.y)
	if !independent_raster || (source.x == 0 && source.y == 0 && source.width == f64(natural_width)
		&& source.height == f64(natural_height)) {
		return ChromiumBackgroundLocalOrigin{x, y, f32(clip.x), f32(clip.y), f32(matrix[4]), f32(matrix[5])}
	}
	return ChromiumBackgroundLocalOrigin{
		0, 0, f32(clip.x) - x, f32(clip.y) - y,
		f32(matrix[4]) + (f32(matrix[0]) * x + f32(matrix[2]) * y),
		f32(matrix[5]) + (f32(matrix[1]) * x + f32(matrix[3]) * y),
	}
}
