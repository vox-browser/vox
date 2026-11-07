module main

import layout
import painting

// Circle coordinates and its local matrix, in the native radial-gradient ABI.
// Blink scales an ellipse around its center rather than normalizing the circle
// to radius one. Keeping that operation order also keeps its GPU rounding.
fn chromium_radial_gradient_geometry(gradient layout.LinearGradient, tile painting.Rect) [12]f32 {
	if radial := gradient.css_radial_geometry {
		if radial.width == f32(tile.width) && radial.height == f32(tile.height) {
			aspect := radial.radius_x / radial.radius_y
			sy := f32(1) / aspect
			projected_y := radial.center_y * sy
			offset_y := radial.center_y - projected_y
			return [radial.center_x, radial.center_y, f32(0), radial.center_x, radial.center_y,
				radial.radius_x, 1, 0, 0, sy, f32(tile.x), f32(tile.y) + offset_y]!
		}
	}
	return [f32(0), 0, 0, 0, 0, 1, f32(gradient.radius_x * tile.width), 0, 0,
		f32(gradient.radius_y * tile.height), f32(tile.x + gradient.center_x * tile.width),
		f32(tile.y + gradient.center_y * tile.height)]!
}
