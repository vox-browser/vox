module main

import dom
import gg
import html
import os

fn test_chromium_webp_paint_truncates_alpha_without_changing_decoder_pixels() {
	$if macos {
		bytes := os.read_bytes(os.join_path(@DIR,
			'Tests/Browser/Brave/input/decode-colors.webp'))!
		bitmap := browser_decode_raster_image_bytes(bytes)!
		original := bitmap.data.clone()
		mut document := html.parse_document('<!doctype html>')
		document.set_font_rendering_policy(.chromium)
		defer { document.finalize() }
		mut app := BrowserApp{
			document: document
			ctx:      gg.new_context(native_rendering: true)
		}
		image := app.create_image_from_resource_bytes('https://webp.test/alpha.webp', bytes)!
		assert image.nr_channels == 7
		$if gcboehm ? { C.GC_gcollect() }
		cached := app.ctx.get_cached_image_by_idx(image.id)
		painted := unsafe { (&u8(cached.data)).vbytes(original.len) }
		assert painted[16..20] == [u8(10), 40, 80, 128]
		assert bitmap.data == original
		assert chromium_webp_paint_pixels([u8(254), 128, 1, 128]) == [u8(127), 64, 0, 128]
		assert browser_decoded_image_data(dom.URL{ value: 'https://webp.test/alpha.webp' }, bytes)!.intrinsic_width()? == 4
		rounding := os.read_bytes(os.join_path(@DIR,
			'Tests/Browser/Brave/input/decode-alpha-rounding.webp'))!
		rounding_image := app.create_image_from_resource_bytes('https://webp.test/rounding.webp',
			rounding)!
		assert rounding_image.nr_channels == 7
		assert unsafe { (&u8(rounding_image.data)).vbytes(4) } == [u8(127), 64, 0, 128]
		tagged := os.read_bytes(os.join_path(@DIR,
			'Tests/Browser/Brave/input/decode-alpha-tagged.webp'))!
		tagged_image := app.create_image_from_resource_bytes('https://webp.test/tagged.webp',
			tagged)!
		if tagged_bitmap := chromium_tagged_webp_paint_bitmap(tagged) {
			assert tagged_image.nr_channels == 7
			assert tagged_bitmap.data[..4] == [u8(127), 64, 0, 128]
			assert unsafe { (&u8(tagged_image.data)).vbytes(4) } == [u8(127), 64, 0, 128]
		} else {
			// Unit-only builds can omit the optional isolated Skia backend.
			assert tagged_image.nr_channels == 6
		}
	}
}
