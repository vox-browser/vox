module main

import dom
import gg
import sokol.gfx

#include "native_jpegxl.h"

$if macos {
	#flag -Wl,-rpath,@VMODROOT/Build/v
}
$if linux {
	#flag -Wl,-rpath,@VMODROOT/Build/linux
}

fn C.vox_jpegxl_available() int
fn C.vox_jpegxl_decode_rgba(&u8, u64, &i32, &i32, &i32) &u8
fn C.vox_jpegxl_decode_paint_rgba(&u8, u64, &i32, &i32, &i32) &u8
fn C.vox_jpegxl_free(&u8, u64)

fn image_bytes_are_jpegxl(bytes []u8) bool {
	return (bytes.len >= 2 && bytes[0] == 0xff && bytes[1] == 0x0a)
		|| (bytes.len >= 12 && bytes[..12] == [u8(0), 0, 0, 12, 0x4a, 0x58, 0x4c, 0x20, 13, 10,
			0x87, 10])
}

fn browser_decode_jpegxl_image_bytes(bytes []u8) !&dom.Bitmap_ {
	return browser_jpegxl_bitmap(bytes, false)
}

fn browser_jpegxl_bitmap(bytes []u8, premultiply bool) !&dom.Bitmap_ {
	if !image_bytes_are_jpegxl(bytes) { return error('Invalid JPEG XL signature') }
	mut width := i32(0)
	mut height := i32(0)
	mut pitch := i32(0)
	decoded := if premultiply {
		C.vox_jpegxl_decode_paint_rgba(bytes.data, u64(bytes.len), &width, &height, &pitch)
	} else {
		C.vox_jpegxl_decode_rgba(bytes.data, u64(bytes.len), &width, &height, &pitch)
	}
	if decoded == unsafe { nil } {
		return error('Invalid or unsupported static sRGB JPEG XL image')
	}
	defer { C.vox_jpegxl_free(decoded, u64(pitch) * u64(height)) }
	mut pixels := []u8{len: int(pitch) * int(height)}
	unsafe { vmemcpy(pixels.data, decoded, pixels.len) }
	return &dom.Bitmap_{
		width:                    int(width)
		height:                   int(height)
		pitch:                    int(pitch)
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
