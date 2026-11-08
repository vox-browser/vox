module main

import dom
import encoding.base64
import html
import layout
import os

// Responses are decoded while their document's native storage is entered, as
// in navigation; deferred pixels are read later, outside it.
fn deferred_png_document() &dom.Document {
	mut document := html.parse_document('<!doctype html><p>Deferred PNG</p>')
	document.enable_native_storage()
	return document
}

// A 2×2 PNG with distinct pixels. stb's realloc path crashes in
// non-production `-prealloc -gc none` test builds with or without deferral,
// so those builds check sizes and deferral but skip the pixel reads below.
const deferred_png_pixels = 'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAFElEQVR4nGP4z8DwHwSZGME0AwMAPu0F/jV/xAYAAAAASUVORK5CYII='

fn deferred_png_small() []u8 {
	return base64.decode(deferred_png_pixels)
}

fn deferred_png_fixture() []u8 {
	return os.read_bytes(os.join_path(@VMODROOT, 'Tests/Browser/Brave/resources/discord-page-gradient.png')) or {
		panic(err)
	}
}

fn test_png_stream_natural_size_reads_complete_ihdr_streams_only() {
	bytes := deferred_png_fixture()
	width, height := png_stream_natural_size(bytes) or { panic('no PNG size') }
	assert width == 131 && height == 768
	assert png_stream_natural_size(bytes[..bytes.len - 1]) == none
	mut bad_depth := bytes.clone()
	bad_depth[24] = 3
	assert png_stream_natural_size(bad_depth) == none
	mut zero := bytes.clone()
	zero[16], zero[17], zero[18], zero[19] = 0, 0, 0, 0
	assert png_stream_natural_size(zero) == none
	assert png_stream_natural_size('GIF89a'.bytes()) == none
}

// A PNG response is available with its natural size before its pixels are
// decoded; the first pixel read produces exactly the eagerly decoded pixels.
fn test_png_image_data_defers_pixels_until_read_and_matches_the_eager_decode() {
	mut document := deferred_png_document()
	defer { document.finalize() }
	mut allocations := document.enter_native_storage()
	bytes := deferred_png_small()
	decoded := browser_decoded_image_data(dom.URL{ value: 'https://images.test/pixels.png' }, bytes) or {
		panic(err)
	}
	allocations.finish()
	assert decoded.is_cors_cross_origin()
	assert decoded.intrinsic_width() or { 0 } == 2
	assert decoded.intrinsic_height() or { 0 } == 2
	frame := decoded.frame(0) or { panic('missing frame') }
	deferred := frame.deferred_bitmap()
	assert !deferred.has_pixels()
	assert decoded.external_memory_size() == uint(2 * 2 * 4)
	assert !deferred.has_pixels()
	assert deferred.native_rows_are_top_down
	assert deferred.native_resource_replay_compatible == browser_raster_can_share_native_pixels(bytes)
	$if prealloc { return }
	eager := browser_decode_raster_image_bytes(bytes) or { panic(err) }
	pixels := frame.bitmap()
	assert deferred.has_pixels()
	assert pixels.width == eager.width && pixels.height == eager.height && pixels.pitch == eager.pitch
	assert pixels.data == eager.data
	assert pixels.data == [u8(255), 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 0, 255]
}

fn test_png_with_corrupt_image_data_keeps_its_size_and_paints_transparent() {
	mut document := deferred_png_document()
	defer { document.finalize() }
	mut allocations := document.enter_native_storage()
	mut bytes := deferred_png_small()
	// Replace the IDAT payload (after its length and type) with invalid zlib data.
	for index in 41 .. bytes.len - 16 {
		bytes[index] = 0xff
	}
	assert png_stream_natural_size(bytes) != none
	decoded := browser_decoded_image_data(dom.URL{ value: 'https://images.test/corrupt.png' }, bytes) or {
		panic(err)
	}
	allocations.finish()
	frame := decoded.frame(0) or { panic('missing frame') }
	assert frame.width() == 2 && frame.height() == 2
	$if prealloc { return }
	eager := browser_decode_raster_image_bytes(bytes) or { unsafe { &dom.Bitmap_(nil) } }
	assert voidptr(eager) == unsafe { nil }
	pixels := frame.bitmap()
	assert pixels.data.len == 2 * 2 * 4
	assert pixels.data.all(it == 0)
}

// Recording keeps the request bitmap without its pixels; only drawing decodes.
fn test_replaced_image_pixels_decode_only_for_the_drawn_command() {
	mut document := deferred_png_document()
	defer { document.finalize() }
	mut allocations := document.enter_native_storage()
	bytes := deferred_png_small()
	bitmap := browser_deferred_png_bitmap(bytes) or { panic('not deferred') }
	allocations.finish()
	mut compatible := unsafe { &dom.Bitmap_(bitmap) }
	compatible.native_resource_replay_compatible = true
	command := layout.PaintCommand{
		kind: 'draw_replaced_image'
		replaced_image_bitmap: bitmap
	}
	shared := replaced_image_bitmap_for_renderer(&command, true) or { panic('missing bitmap') }
	assert voidptr(shared) == voidptr(bitmap)
	assert !bitmap.has_pixels()
	$if prealloc { return }
	drawn := replaced_image_pixels_for_renderer(&command, true) or { panic('missing pixels') }
	assert voidptr(drawn) == voidptr(bitmap)
	assert bitmap.has_pixels()
	assert drawn.data.len == drawn.pitch * drawn.height
}
