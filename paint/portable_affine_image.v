module main

import gg
import layout
import painting

fn (app &BrowserApp) draw_portable_affine_image(command &layout.PaintCommand,
	config gg.DrawImageConfig, rect painting.Rect, page_x f32, page_y f32, scroll_y f64) {
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
	renderer.texture(image.simg, image.ssmp)
	renderer.begin_quads()
	renderer.c4b(config.color.r, config.color.g, config.color.b, config.color.a)
	renderer.v3f_t2f(top_left_x * scale, top_left_y * scale, 0, u0, v0)
	renderer.v3f_t2f(top_right_x * scale, top_right_y * scale, 0, u1, v0)
	renderer.v3f_t2f(bottom_right_x * scale, bottom_right_y * scale, 0, u1, v1)
	renderer.v3f_t2f(bottom_left_x * scale, bottom_left_y * scale, 0, u0, v1)
	renderer.end()
	renderer.disable_texture()
}
