module main

import compress.deflate
import gg
import os
import dom

fn C.native_png_has_icc_profile(bytes &u8, length uint) int
fn C.native_png_icc_channel_marker() int
// The callback has the native VoxPngIccInflate signature.
fn C.native_png_icc_set_inflater(inflate voidptr)

// PNG iCCP metadata is a zlib stream. The native PNG profile bridge finds the
// chunk; vlib's V inflater decodes it, as Vox links no zlib.
fn init() {
	$if macos {
		C.native_png_icc_set_inflater(voidptr(png_icc_inflate_profile))
	}
}

struct PngIccInflation {
	limit int
mut:
	output   []u8
	exceeded bool
}

fn png_icc_collect(chunk []u8, userdata voidptr) int {
	mut inflation := unsafe { &PngIccInflation(userdata) }
	if inflation.output.len + chunk.len > inflation.limit {
		inflation.exceeded = true
		return 0
	}
	inflation.output << chunk
	return chunk.len
}

// Decodes at most `limit` bytes, aborting as soon as the profile would exceed
// it, and returns malloc'd storage the native caller frees.
fn png_icc_inflate_profile(input &u8, length uint, limit uint, output_length &uint) &u8 {
	if isnil(input) || u64(length) > u64(max_int) || u64(limit) > u64(max_int) {
		return unsafe { nil }
	}
	data := unsafe { input.vbytes(int(length)) }
	deflate.validate_zlib_header(data) or { return unsafe { nil } }
	mut inflation := &PngIccInflation{
		limit: int(limit)
	}
	deflate.decompress_with_callback(data, png_icc_collect, inflation) or { return unsafe { nil } }
	if inflation.exceeded || inflation.output.len == 0 {
		return unsafe { nil }
	}
	output := unsafe { &u8(C.malloc(uint(inflation.output.len))) }
	if isnil(output) {
		return unsafe { nil }
	}
	unsafe {
		vmemcpy(output, inflation.output.data, inflation.output.len)
		*output_length = uint(inflation.output.len)
	}
	return output
}

fn native_png_channel_marker(bitmap &dom.Bitmap_, bytes []u8, chromium bool) int {
	$if macos {
		if chromium && bitmap.native_rows_are_top_down
			&& C.native_png_has_icc_profile(bytes.data, uint(bytes.len)) != 0 {
			return C.native_png_icc_channel_marker()
		}
	}
	return native_bitmap_channel_marker(bitmap, false)
}

fn (mut app BrowserApp) create_local_image_with_profile(image_url string, path string) !gg.Image {
	mut file := os.open(path) or { return app.ctx.create_image(path) }
	prefix := file.read_bytes(144)
	file.close()
	if image_bytes_are_jpegxl(prefix) {
		return app.create_jpegxl_resource_image(app.background_image_bytes(image_url)!)
	}
	if image_bytes_are_avif(prefix) {
		return app.create_avif_resource_image(app.background_image_bytes(image_url)!)
	}
	$if macos {
		if app.ctx.native_rendering && app.document != unsafe { nil }
			&& app.document.font_rendering_policy() == .chromium
			&& prefix.len >= 3 && prefix[0] == 0xff && prefix[1] == 0xd8 && prefix[2] == 0xff {
			bytes := app.background_image_bytes(image_url) or { return app.ctx.create_image(path) }
			// AppKit reports point dimensions from JPEG resolution metadata.
			// Use the fetched-image decoder's pixel size and chroma policy for
			// local files too, including JPEG bytes under another extension.
			return app.create_image_from_resource_bytes(image_url, bytes)
		}
		if app.ctx.native_rendering && app.document != unsafe { nil }
			&& app.document.font_rendering_policy() == .chromium && image_bytes_are_webp(prefix) {
			animated := prefix.len >= 21 && prefix[12..16].bytestr() == 'VP8X'
				&& prefix[20] & 2 != 0
			if !animated {
				bytes := app.background_image_bytes(image_url) or { return app.ctx.create_image(path) }
				// Static file images need the same libwebp alpha multiplication
				// and tagged-color upload as fetched images. Keep animated providers.
				return app.create_image_from_resource_bytes(image_url, bytes)
			}
		}
		if app.ctx.native_rendering && path.to_lower().ends_with('.png')
			&& app.document != unsafe { nil }
			&& app.document.font_rendering_policy() == .chromium {
			bytes := app.background_image_bytes(image_url) or { return app.ctx.create_image(path) }
			// ColorSync also interprets PNG gamma/chromaticity metadata without
			// an ICC chunk. Keep file and fetched PNG pixels and tagging alike.
			return app.create_image_from_resource_bytes(image_url, bytes)
		}
	}
	return app.ctx.create_image(path)
}
