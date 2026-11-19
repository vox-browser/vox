module main

import gg
import platform

struct PortableRasterImage {
	image_id int
	width    int
	height   int
}

fn (mut app BrowserApp) draw_portable_raster_image(x f32, y f32, width int, height int, pixels []u8) {
	app.draw_portable_raster_texture(gg.Rect{x, y, f32(width) / app.ctx.scale, f32(height) / app.ctx.scale}, width, height, pixels)
}

fn (mut app BrowserApp) draw_portable_raster_texture(destination gg.Rect, width int, height int,
	pixels []u8) {
	app.draw_portable_raster_texture_with_alpha(destination, width, height, pixels, 255)
}

fn (mut app BrowserApp) draw_portable_raster_texture_with_alpha(destination gg.Rect, width int,
	height int, pixels []u8, alpha u8) {
	app.upload_portable_raster_texture(destination, width, height, pixels, alpha, false)
}

fn (mut app BrowserApp) upload_portable_raster_texture(destination gg.Rect, width int,
	height int, pixels []u8, alpha u8, retain_svg_clip bool) {
	// Sokol allows one streaming update per texture per frame.
	index := app.portable_raster_image_index
	app.portable_raster_image_index++
	app.invalidate_portable_raster_image(index, retain_svg_clip)
	persistent := platform.enter_persistent()
	mut slot := if index < app.portable_raster_images.len {
		app.portable_raster_images[index]
	} else {
		PortableRasterImage{ image_id: -1 }
	}
	if slot.image_id < 0 || slot.width != width || slot.height != height {
		if slot.image_id >= 0 { app.ctx.remove_cached_image_by_idx(slot.image_id) }
		slot = PortableRasterImage{
			image_id: app.ctx.new_streaming_image(width, height, 4,
				min_filter: .nearest
				mag_filter: .nearest
			)
			width:    width
			height:   height
		}
	}
	if index < app.portable_raster_images.len {
		app.portable_raster_images[index] = slot
	} else {
		app.portable_raster_images << slot
	}
	platform.leave_persistent(persistent)
	app.ctx.update_pixel_data(slot.image_id, pixels.data)
	app.ctx.draw_image_with_config(img_id: slot.image_id, img_rect: destination, color: gg.Color{255, 255, 255, alpha})
}

fn (mut app BrowserApp) invalidate_portable_raster_image(index int, retain_svg_clip bool) {
	if index < portable_web_font_texture_slots && app.portable_web_font_textures[index].key.generation != 0 {
		app.portable_web_font_textures[index] = PortableWebFontTexture{}
		if app.portable_web_font_scroll_textures != unsafe { nil } {
			app.portable_web_font_scroll_textures.entries[index].valid = false
		}
	}
	app.invalidate_portable_svg_raster(index, retain_svg_clip)
}

fn (mut app BrowserApp) finish_portable_raster_images() {
	for app.portable_raster_images.len > app.portable_raster_image_index {
		app.invalidate_portable_raster_image(app.portable_raster_images.len - 1, false)
		slot := app.portable_raster_images.pop()
		app.ctx.remove_cached_image_by_idx(slot.image_id)
	}
}
