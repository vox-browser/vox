module main

import dom
import gg
import jpegxl
import platform
import sokol.gfx

fn image_bytes_are_jpegxl(bytes []u8) bool {
	return (bytes.len >= 2 && bytes[0] == 0xff && bytes[1] == 0x0a)
		|| (bytes.len >= 12 && bytes[..12] == [u8(0), 0, 0, 12, 0x4a, 0x58, 0x4c, 0x20, 13, 10,
			0x87, 10])
}

fn browser_decode_jpegxl_image_bytes(bytes []u8) !&dom.Bitmap_ {
	return browser_jpegxl_bitmap(bytes, false)
}

// The pure V decoder handles static 8-bit sRGB/gray images. Its float planes
// and intermediate buffers stay in a thread scratch scope; only the final RGBA
// rows are copied to the caller's allocation target.
fn browser_jpegxl_bitmap(bytes []u8, premultiply bool) !&dom.Bitmap_ {
	if !image_bytes_are_jpegxl(bytes) { return error('Invalid JPEG XL signature') }
	scratch := platform.begin_thread_scratch('JPEG XL decode')
	defer { scratch.finish() }
	decoded := jpegxl.decode_rgba(bytes, premultiply) or {
		scratch.leave()
		return error('Invalid or unsupported static sRGB JPEG XL image')
	}
	scratch.leave()
	pixels := decoded.pixels.clone()
	return &dom.Bitmap_{
		width:                    decoded.width
		height:                   decoded.height
		pitch:                    decoded.pitch
		data:                     pixels
		native_rows_are_top_down: true
	}
}

// Native painting premultiplies before the decoder quantizes to bytes, as Brave does.
// Image models and portable uploads retain straight rows for readback.
fn (mut app BrowserApp) create_jpegxl_resource_image(bytes []u8) !gg.Image {
	bitmap := browser_jpegxl_bitmap(bytes, app.ctx.native_rendering)!
	$if macos {
		if app.ctx.native_rendering {
			C.native_tag_image_color_profile(bitmap.data.data, bitmap.width, bitmap.height,
				bytes.data, uint(bytes.len), 0)
		}
	}
	mut image := gg.Image{
		width:          bitmap.width
		height:         bitmap.height
		nr_channels:    if app.ctx.native_rendering {
			native_bitmap_channel_marker(bitmap, true)
		} else {
			4
		}
		ok:             true
		data:           bitmap.data.data
		texture_filter: app.ctx.config.texture_filter
	}
	if !app.ctx.native_rendering && gfx.is_valid() { image.init_sokol_image() }
	image.id = app.ctx.cache_image(image)
	return image
}
