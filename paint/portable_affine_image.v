module main

import gg
import gg.render
import layout
import math
import painting

struct AffineImagePoint {
	x f32
	y f32
}

// Leave room in GG's shared vertex queue for the rest of the frame.
const portable_image_coverage_vertex_limit = 32768

@[inline]
fn affine_image_vertex(renderer &render.Context, origin AffineImagePoint, x_axis AffineImagePoint,
	y_axis AffineImagePoint, u f32, v f32, color gg.Color, alpha u8) {
	renderer.v3f_t2f_c4b(origin.x + u * x_axis.x + v * y_axis.x,
		origin.y + u * x_axis.y + v * y_axis.y, 0, u, v, color.r, color.g, color.b, alpha)
}

// Each slanted edge crosses a band of partially covered device pixels.
// Project a device pixel onto the local axes to find those bands, and
// interpolate coverage across a ring around the fully covered interior.
fn draw_portable_image_edge_coverage(renderer &render.Context, origin AffineImagePoint,
	right AffineImagePoint, bottom AffineImagePoint, color gg.Color) bool {
	x_axis := AffineImagePoint{right.x - origin.x, right.y - origin.y}
	y_axis := AffineImagePoint{bottom.x - origin.x, bottom.y - origin.y}
	slanted_x := x_axis.x != 0 && x_axis.y != 0
	slanted_y := y_axis.x != 0 && y_axis.y != 0
	if !slanted_x && !slanted_y {
		return false
	}
	quads := if slanted_x && slanted_y { 5 } else { 3 }
	if renderer.num_vertices() + quads * 6 > portable_image_coverage_vertex_limit {
		return false
	}
	area := math.abs(x_axis.x * y_axis.y - x_axis.y * y_axis.x)
	u_radius := if slanted_y { (math.abs(y_axis.x) + math.abs(y_axis.y)) / (2 * area) } else { f32(0) }
	v_radius := if slanted_x { (math.abs(x_axis.x) + math.abs(x_axis.y)) / (2 * area) } else { f32(0) }
	if !(u_radius < 0.5 && v_radius < 0.5) {
		// Overlapping bands need a separate coverage calculation.
		return false
	}
	inner := [
		AffineImagePoint{u_radius, v_radius},
		AffineImagePoint{1 - u_radius, v_radius},
		AffineImagePoint{1 - u_radius, 1 - v_radius},
		AffineImagePoint{u_radius, 1 - v_radius},
	]!
	outer := [
		AffineImagePoint{-u_radius, -v_radius},
		AffineImagePoint{1 + u_radius, -v_radius},
		AffineImagePoint{1 + u_radius, 1 + v_radius},
		AffineImagePoint{-u_radius, 1 + v_radius},
	]!
	for point in inner {
		affine_image_vertex(renderer, origin, x_axis, y_axis, point.x, point.y, color, color.a)
	}
	for edge in 0 .. 4 {
		if (edge % 2 == 0 && !slanted_x) || (edge % 2 != 0 && !slanted_y) {
			continue
		}
		next := (edge + 1) % 4
		affine_image_vertex(renderer, origin, x_axis, y_axis, outer[edge].x, outer[edge].y, color, 0)
		affine_image_vertex(renderer, origin, x_axis, y_axis, outer[next].x, outer[next].y, color, 0)
		affine_image_vertex(renderer, origin, x_axis, y_axis, inner[next].x, inner[next].y, color, color.a)
		affine_image_vertex(renderer, origin, x_axis, y_axis, inner[edge].x, inner[edge].y, color, color.a)
	}
	return true
}

fn (app &BrowserApp) draw_portable_affine_image(command &layout.PaintCommand,
	config gg.DrawImageConfig, rect painting.Rect, nearest bool, page_x f32, page_y f32, scroll_y f64) {
	image := config.img
	if !image.simg_ok { return }
	scale := app.ctx.scale
	top_left_x, top_left_y := paint_screen_point(*command, rect.x, rect.y, page_x, page_y, scroll_y)
	top_right_x, top_right_y := paint_screen_point(*command, rect.right(), rect.y, page_x, page_y, scroll_y)
	bottom_right_x, bottom_right_y := paint_screen_point(*command, rect.right(), rect.bottom(), page_x, page_y, scroll_y)
	bottom_left_x, bottom_left_y := paint_screen_point(*command, rect.x, rect.bottom(), page_x, page_y, scroll_y)
	// Pair the clipped source rectangle with the vertices in local order.
	// Sorting the corners by screen position would undo a reflection.
	part := config.part_rect
	u0, v0 := part.x / image.width, part.y / image.height
	u1, v1 := (part.x + part.width) / image.width, (part.y + part.height) / image.height
	renderer := app.ctx.r
	// Keep decoded images available to the CPU renderer as GG's rectangle draw does.
	if image.data != unsafe { nil } {
		image_id := int(image.simg.id)
		if !renderer.is_image_registered(image_id) {
			filter := if image.texture_filter == .linear { 1 } else { 0 }
			renderer.register_image(image_id, image.data, image.width, image.height, 4, filter)
		}
	}
	renderer.load_pipeline(app.ctx.pipeline.alpha)
	renderer.enable_texture()
	renderer.texture(image.simg, portable_image_sampler(image, nearest))
	renderer.begin_quads()
	// The texture sampler clamps the fringe to the full image. A source
	// crop would need the shader to clamp to its own bounds as well.
	covered := u0 == 0 && v0 == 0 && u1 == 1 && v1 == 1
		&& draw_portable_image_edge_coverage(renderer,
			AffineImagePoint{top_left_x * scale, top_left_y * scale},
			AffineImagePoint{top_right_x * scale, top_right_y * scale},
			AffineImagePoint{bottom_left_x * scale, bottom_left_y * scale}, config.color)
	if !covered {
		renderer.c4b(config.color.r, config.color.g, config.color.b, config.color.a)
		renderer.v3f_t2f(top_left_x * scale, top_left_y * scale, 0, u0, v0)
		renderer.v3f_t2f(top_right_x * scale, top_right_y * scale, 0, u1, v0)
		renderer.v3f_t2f(bottom_right_x * scale, bottom_right_y * scale, 0, u1, v1)
		renderer.v3f_t2f(bottom_left_x * scale, bottom_left_y * scale, 0, u0, v1)
	}
	renderer.end()
	renderer.disable_texture()
}
