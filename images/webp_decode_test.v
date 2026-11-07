module main

import os
import gg

fn test_static_webp_decode_preserves_rgba_alpha_and_top_down_rows() {
	$if macos {
		bytes := os.read_bytes(os.join_path(@VMODROOT, 'Tests/Browser/Brave/input/decode-colors.webp'))!
		bitmap := browser_decode_raster_image_bytes(bytes)!
		assert bitmap.width == 4
		assert bitmap.height == 2
		assert bitmap.pitch == 16
		assert bitmap.native_rows_are_top_down
		assert bitmap.data == [u8(255), 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 0, 0, 0, 0,
			20, 80, 160, 128, 250, 200, 100, 255, 0, 0, 0, 255, 255, 255, 255, 255]
		_ := browser_decode_raster_image_bytes('RIFFxxxxWEBPinvalid'.bytes()) or { return }
		assert false, 'Malformed WebP decoded successfully'
	}
}

fn test_static_webp_native_image_cache_uses_the_document_decoders_pixels() {
	$if macos {
		bytes := os.read_bytes(os.join_path(@VMODROOT, 'Tests/Browser/Brave/input/decode-colors.webp'))!
		bitmap := browser_decode_raster_image_bytes(bytes)!
		mut app := BrowserApp{ ctx: gg.new_context(native_rendering: true) }
		image := app.create_image_from_resource_bytes('https://webp.test/rows.webp', bytes)!
		assert image.path == ''
		assert image.nr_channels == 6
		assert image.width == bitmap.width && image.height == bitmap.height
		cached := app.ctx.get_cached_image_by_idx(image.id)
		assert cached.nr_channels == 6
		assert unsafe { (&u8(cached.data)).vbytes(bitmap.data.len) } == bitmap.data
	}
}
