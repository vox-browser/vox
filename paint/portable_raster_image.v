module main

import platform

struct PortableRasterImage {
	image_id int
	width    int
	height   int
}

fn (mut app BrowserApp) draw_portable_raster_image(x f32, y f32, width int, height int, pixels []u8) {
	// Sokol allows one streaming update per texture per frame.
	index := app.portable_raster_image_index
	app.portable_raster_image_index++
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
	app.ctx.draw_image_by_id(x, y, f32(width) / app.ctx.scale, f32(height) / app.ctx.scale, slot.image_id)
}

fn (mut app BrowserApp) finish_portable_raster_images() {
	for app.portable_raster_images.len > app.portable_raster_image_index {
		slot := app.portable_raster_images.pop()
		app.ctx.remove_cached_image_by_idx(slot.image_id)
	}
}
