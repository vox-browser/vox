module main

import dom
import gg
import html
import os

fn test_chromium_local_webp_keeps_the_fetched_alpha_rounding_and_row_order() {
	$if macos {
		mut document := html.parse_document('<!doctype html>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		mut app := BrowserApp{document: document, ctx: gg.new_context(native_rendering: true)}
		for name in ['decode-alpha-rounding.webp', 'decode-colors.webp'] {
			path := os.join_path(@VMODROOT, 'Tests/Browser/Brave/input', name)
			bytes := os.read_bytes(path)!
			local := app.create_local_image_with_profile('file://${path}', path)!
			fetched := app.create_image_from_resource_bytes('https://webp.test/${name}', bytes)!
			assert local.path == ''
			assert local.nr_channels == 7 && fetched.nr_channels == 7
			assert local.width == fetched.width && local.height == fetched.height
			count := local.width * local.height * 4
			assert unsafe { (&u8(local.data)).vbytes(count) } == unsafe { (&u8(fetched.data)).vbytes(count) }
			if name == 'decode-alpha-rounding.webp' {
				assert unsafe { (&u8(local.data)).vbytes(4) } == [u8(127), 64, 0, 128]
			}
		}
		// Other renderer policies retain the native file provider.
		document.set_font_rendering_policy(.libweb)
		path := os.join_path(@VMODROOT, 'Tests/Browser/Brave/input/decode-colors.webp')
		legacy := app.create_local_image_with_profile('file://${path}', path)!
		assert legacy.path == path
	}
}

fn test_chromium_webp_paint_truncates_alpha_without_changing_decoder_pixels() {
	$if macos {
		bytes := os.read_bytes(os.join_path(@VMODROOT,
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
		rounding := os.read_bytes(os.join_path(@VMODROOT,
			'Tests/Browser/Brave/input/decode-alpha-rounding.webp'))!
		rounding_image := app.create_image_from_resource_bytes('https://webp.test/rounding.webp',
			rounding)!
		assert rounding_image.nr_channels == 7
		assert unsafe { (&u8(rounding_image.data)).vbytes(4) } == [u8(127), 64, 0, 128]
		tagged := os.read_bytes(os.join_path(@VMODROOT,
			'Tests/Browser/Brave/input/decode-alpha-tagged.webp'))!
		tagged_image := app.create_image_from_resource_bytes('https://webp.test/tagged.webp',
			tagged)!
		// ICC-tagged WebP decodes straight before its color transform.
		assert tagged_image.nr_channels == 6
	}
}
