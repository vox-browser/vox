module main

import dom
import gg
import imageraster
import layout
import math
import os
import painting
import platform
import sokol.gfx

const portable_bitmap_upload_diagnostics = os.getenv('VOX_PORTABLE_BITMAP_UPLOAD_DIAGNOSTICS') == '1'
const disable_portable_canvas_upload_reuse = os.getenv('VOX_DISABLE_PORTABLE_CANVAS_UPLOAD_REUSE') == '1'

struct PortableCanvasImage {
	mut:
	image_id int = -1
	width int
	height int
	nearest bool
	video_frame painting.VideoFrameResourceIdentity
	bitmap_revision u64
}

struct PortableBitmapStream {
	bitmap &dom.Bitmap_
	nearest bool
	video_frame painting.VideoFrameResourceIdentity
}

fn (mut app BrowserApp) portable_bitmap_texture(stream PortableBitmapStream) &gg.Image {
	bitmap := stream.bitmap
	// Allocate at most one slot for each texture drawn this frame. The raster
	// fallback has its own output texture and does not consume a source slot.
	index := app.portable_canvas_image_index
	app.portable_canvas_image_index++
	persistent := platform.enter_persistent()
	mut slot := if index < app.portable_canvas_images.len { app.portable_canvas_images[index] } else { PortableCanvasImage{} }
	if slot.image_id < 0 || slot.width != bitmap.width || slot.height != bitmap.height || slot.nearest != stream.nearest {
		if slot.image_id >= 0 { app.ctx.remove_cached_image_by_idx(slot.image_id) }
		filter := if stream.nearest { gfx.Filter.nearest } else { gfx.Filter.linear }
		slot = PortableCanvasImage{
			image_id: app.ctx.new_streaming_image(bitmap.width, bitmap.height, 4, min_filter: filter, mag_filter: filter)
			width: bitmap.width
			height: bitmap.height
			nearest: stream.nearest
		}
	}
	// Each upload replaces both keys. Canvas, posters and video can share a
	// slot across frames, and untracked bitmaps always upload their pixels.
	revision := if disable_portable_canvas_upload_reuse { u64(0) } else { bitmap.upload_revision() }
	needs_upload := if stream.video_frame.source != 0 {
		slot.video_frame != stream.video_frame
	} else {
		revision == 0 || slot.bitmap_revision != revision
	}
	slot.video_frame = stream.video_frame
	slot.bitmap_revision = revision
	if index < app.portable_canvas_images.len { app.portable_canvas_images[index] = slot } else { app.portable_canvas_images << slot }
	platform.leave_persistent(persistent)
	if needs_upload {
		pixels := if bitmap.alpha_type in [u8(0), 2] {
			imageraster.unpremultiply_canvas_rgba(bitmap.data[..bitmap.pitch * bitmap.height])
		} else { bitmap.data }
		app.ctx.update_pixel_data(slot.image_id, pixels.data)
		if portable_bitmap_upload_diagnostics {
			eprintln('VOX_PORTABLE_BITMAP upload=${bitmap.width}x${bitmap.height}')
		}
	}
	return app.ctx.get_cached_image_by_idx(slot.image_id)
}

$if linux || windows {
	fn (mut app BrowserApp) draw_portable_canvas(command &layout.PaintCommand, bitmap &dom.Bitmap_, result painting.CanvasPaintResult, page_x f32, page_y f32, scroll_y f64) {
		app.draw_portable_bitmap(command, bitmap, result.content.destination, result.clip_rect,
			result.content.scaling, painting.VideoFrameResourceIdentity{}, page_x, page_y, scroll_y)
	}

	fn (mut app BrowserApp) draw_portable_bitmap(command &layout.PaintCommand, bitmap &dom.Bitmap_,
		destination painting.IntRect, clip painting.IntRect, scaling painting.ScalingMode,
		video_frame painting.VideoFrameResourceIdentity, page_x f32, page_y f32, scroll_y f64) {
		left, top := math.max(f64(destination.x), f64(clip.x)), math.max(f64(destination.y), f64(clip.y))
		right, bottom := math.min(f64(destination.right()), f64(clip.right())), math.min(f64(destination.bottom()), f64(clip.bottom()))
		if right <= left || bottom <= top { return }
		stream := PortableBitmapStream{bitmap, scaling == .nearest_neighbor, video_frame}
		x1, y1 := paint_screen_point(*command, left, top, page_x, page_y, scroll_y)
		x2, y2 := paint_screen_point(*command, right, bottom, page_x, page_y, scroll_y)
		mut config := gg.DrawImageConfig{
			img_rect: gg.Rect{math.min(x1,x2),math.min(y1,y2),math.abs(x2-x1),math.abs(y2-y1)}
			part_rect: gg.Rect{f32((left-f64(destination.x))*f64(bitmap.width)/f64(destination.width)),f32((top-f64(destination.y))*f64(bitmap.height)/f64(destination.height)),f32((right-left)*f64(bitmap.width)/f64(destination.width)),f32((bottom-top)*f64(bitmap.height)/f64(destination.height))}
			color: gg.rgba(255,255,255,u8(clamp(command.opacity*255,0,255)))
		}
		if !disable_portable_rounded_image_clip {
			rounded := if canvas := command.canvas_paintable {
				canvas.border_radii.has_any_radius()
			} else if video := command.video_paintable {
				video.border_radii.has_any_radius()
			} else {
				false
			}
			if rounded {
				data := replaced_image_gpu_clip_data(command, clip, painting.CornerRadii{}, -1)
				geometry := painting.DrawScaledDecodedImageFrame{
					destination: destination
					clip_rect: clip
					scaling: scaling
				}
				if app.draw_portable_rounded_bitmap(command, config, geometry, data, stream,
					page_x, page_y, scroll_y) { return }
			}
		}
		config.img = app.portable_bitmap_texture(stream)
		matrix := command.transform
		if matrix[1] != 0 || matrix[2] != 0 || matrix[0] < 0 || matrix[3] < 0 {
			app.draw_portable_affine_image(command, config, painting.Rect{left, top, right - left, bottom - top},
				false, page_x, page_y, scroll_y)
			return
		}
		app.ctx.draw_image_with_config(config)
	}

	fn (mut app BrowserApp) finish_portable_canvas_frame() {
		for app.portable_canvas_images.len > app.portable_canvas_image_index {
			slot := app.portable_canvas_images.pop()
			app.ctx.remove_cached_image_by_idx(slot.image_id)
		}
	}
}
