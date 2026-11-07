module main

import dom
import gg
import sokol.gfx

#include "@VMODROOT/native_avif.h"
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
fn C.vox_avif_decode_yuv(&u8, u64, &i32, &i32, &i32, &i32) &u8
fn C.vox_avif_yuv_paint_supported() int

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
	$if macos {
		if app.ctx.native_rendering && app.document != unsafe { nil }
			&& app.document.font_rendering_policy() == .chromium
			&& C.native_webp_yuv_paint_supported() != 0 && C.vox_avif_yuv_paint_supported() != 0 {
			if image := app.create_avif_yuv_image(bytes) { return image }
		}
	}
	bitmap := browser_avif_bitmap(bytes, app.ctx.native_rendering)!
	mut image := gg.Image{width: bitmap.width, height: bitmap.height,
		nr_channels: if app.ctx.native_rendering { native_bitmap_channel_marker(bitmap, true) } else { 4 },
		ok: true, data: bitmap.data.data, texture_filter: app.ctx.config.texture_filter}
	if !app.ctx.native_rendering && gfx.is_valid() { image.init_sokol_image() }
	image.id = app.ctx.cache_image(image)
	return image
}

fn (mut app BrowserApp) create_avif_yuv_image(bytes []u8) ?gg.Image {
	mut width := i32(0)
	mut height := i32(0)
	mut size := i32(0)
	mut subsampling := i32(0)
	planes := C.vox_avif_decode_yuv(bytes.data, u64(bytes.len), &width, &height, &size, &subsampling)
	if planes == unsafe { nil } { return none }
	defer { C.vox_avif_release(planes) }
	mut pixels := []u8{len: int(size)}
	unsafe { vmemcpy(pixels.data, planes, pixels.len) }
	mut image := gg.Image{width: int(width), height: int(height),
		nr_channels: match subsampling { 0 { 10 } 1 { 12 } else { 9 } }, ok: true, data: pixels.data}
	image.id = app.ctx.cache_image(image)
	return image
}
