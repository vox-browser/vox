module main

import dom
import gg
import imageraster
import layout
import math
import painting
import platform
import sokol.gfx

struct PortableCanvasImage {
	image_id int = -1
	width int
	height int
	nearest bool
}

$if linux || windows {
	fn (mut app BrowserApp) draw_portable_canvas(command &layout.PaintCommand, bitmap &dom.Bitmap_, result painting.CanvasPaintResult, page_x f32, page_y f32, scroll_y f64) {
		// Each displayed canvas gets one streaming image per frame, so Sokol
		// never receives multiple updates to the same image in a single frame.
		index := app.portable_canvas_image_index
		app.portable_canvas_image_index++
		nearest := result.content.scaling == .nearest_neighbor
		persistent := platform.enter_persistent()
		mut slot := if index < app.portable_canvas_images.len { app.portable_canvas_images[index] } else { PortableCanvasImage{} }
		if slot.image_id < 0 || slot.width != bitmap.width || slot.height != bitmap.height || slot.nearest != nearest {
			if slot.image_id >= 0 { app.ctx.remove_cached_image_by_idx(slot.image_id) }
			filter := if nearest { gfx.Filter.nearest } else { gfx.Filter.linear }
			slot = PortableCanvasImage{
				image_id: app.ctx.new_streaming_image(bitmap.width, bitmap.height, 4, min_filter: filter, mag_filter: filter)
				width: bitmap.width
				height: bitmap.height
				nearest: nearest
			}
		}
		if index < app.portable_canvas_images.len { app.portable_canvas_images[index] = slot } else { app.portable_canvas_images << slot }
		platform.leave_persistent(persistent)
		pixels := if bitmap.alpha_type in [u8(0), 2] {
			imageraster.unpremultiply_canvas_rgba(bitmap.data[..bitmap.pitch * bitmap.height])
		} else { bitmap.data }
		app.ctx.update_pixel_data(slot.image_id, pixels.data)
		image := app.ctx.get_cached_image_by_idx(slot.image_id)
		destination, clip := result.content.destination, result.clip_rect
		left, top := math.max(f64(destination.x), f64(clip.x)), math.max(f64(destination.y), f64(clip.y))
		right, bottom := math.min(f64(destination.right()), f64(clip.right())), math.min(f64(destination.bottom()), f64(clip.bottom()))
		if right <= left || bottom <= top { return }
		x1, y1 := paint_screen_point(*command, left, top, page_x, page_y, scroll_y)
		x2, y2 := paint_screen_point(*command, right, bottom, page_x, page_y, scroll_y)
		app.ctx.draw_image_with_config(
			img: image
			img_rect: gg.Rect{math.min(x1,x2),math.min(y1,y2),math.abs(x2-x1),math.abs(y2-y1)}
			part_rect: gg.Rect{f32((left-f64(destination.x))*f64(bitmap.width)/f64(destination.width)),f32((top-f64(destination.y))*f64(bitmap.height)/f64(destination.height)),f32((right-left)*f64(bitmap.width)/f64(destination.width)),f32((bottom-top)*f64(bitmap.height)/f64(destination.height))}
			color: gg.rgba(255,255,255,u8(clamp(command.opacity*255,0,255)))
		)
	}

	fn (mut app BrowserApp) finish_portable_canvas_frame() {
		for app.portable_canvas_images.len > app.portable_canvas_image_index {
			slot := app.portable_canvas_images.pop()
			app.ctx.remove_cached_image_by_idx(slot.image_id)
		}
	}
}
