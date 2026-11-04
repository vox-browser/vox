module main

import dom
import gg
import sokol.gfx

#include "native_avif.h"
$if macos {
	#flag -Wl,-rpath,@VMODROOT/Build/v
}
$if linux {
	#flag -Wl,-rpath,@VMODROOT/Build/linux
}

fn C.vox_avif_available() int
fn C.vox_avif_is_avif(&u8, u64) int
fn C.vox_avif_decode_rgba(&u8, u64, int, &i32, &i32, &i32) &u8
fn C.vox_avif_release(&u8)

fn image_bytes_are_avif(bytes []u8) bool {
	return bytes.len >= 16 && bytes[4..8].bytestr() == 'ftyp'
		&& C.vox_avif_is_avif(bytes.data, u64(bytes.len)) != 0
}

fn browser_avif_bitmap(bytes []u8, premultiply bool) !&dom.Bitmap_ {
	mut width := i32(0)
	mut height := i32(0)
	mut pitch := i32(0)
	decoded := C.vox_avif_decode_rgba(bytes.data, u64(bytes.len), int(premultiply),
		&width, &height, &pitch)
	if decoded == unsafe { nil } { return error('Invalid or unsupported static sRGB AVIF image') }
	defer { C.vox_avif_release(decoded) }
	mut pixels := []u8{len: int(pitch) * int(height)}
	unsafe { vmemcpy(pixels.data, decoded, pixels.len) }
	return &dom.Bitmap_{width: int(width), height: int(height), pitch: int(pitch),
		data: pixels, native_rows_are_top_down: true}
}

fn (mut app BrowserApp) create_avif_resource_image(bytes []u8) !gg.Image {
	bitmap := browser_avif_bitmap(bytes, app.ctx.native_rendering)!
	mut image := gg.Image{width: bitmap.width, height: bitmap.height,
		nr_channels: if app.ctx.native_rendering { native_bitmap_channel_marker(bitmap, true) } else { 4 },
		ok: true, data: bitmap.data.data, texture_filter: app.ctx.config.texture_filter}
	if !app.ctx.native_rendering && gfx.is_valid() { image.init_sokol_image() }
	image.id = app.ctx.cache_image(image)
	return image
}
