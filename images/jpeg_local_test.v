module main

import gg
import html
import os

fn test_local_jpeg_uses_pixel_dimensions_and_the_same_decode_as_fetched_bytes() {
	$if macos {
		mut document := html.parse_document('<!doctype html>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		mut app := BrowserApp{document: document, ctx: gg.new_context(native_rendering: true)}
		// The 16x16 image declares 96 DPI: AppKit's point size is only 12x12.
		path := os.join_path(@VMODROOT, 'Tests/Browser/Brave/resources/avatar-jpeg-source.jpg')
		bytes := os.read_bytes(path)!
		fetched := app.create_image_from_resource_bytes('https://images.test/photo.jpg', bytes)!
		local := app.create_local_image_with_profile('file://${path}', path)!
		assert local.width == 16 && local.height == 16
		assert local.path == '' && local.nr_channels == 6
		assert local.width == fetched.width && local.height == fetched.height
		assert unsafe { (&u8(local.data)).vbytes(16 * 16 * 4) } == unsafe { (&u8(fetched.data)).vbytes(16 * 16 * 4) }
		folder := os.join_path(os.temp_dir(), 'vox-local-jpeg-${os.getpid()}')
		os.mkdir_all(folder)!
		defer { os.rmdir_all(folder) or {} }
		other := os.join_path(folder, 'avatar.bin')
		os.write_file_array(other, bytes)!
		aliased := app.create_local_image_with_profile('file://${other}', other)!
		assert aliased.width == 16 && aliased.height == 16 && aliased.path == ''
		assert unsafe { (&u8(aliased.data)).vbytes(16 * 16 * 4) } == unsafe { (&u8(fetched.data)).vbytes(16 * 16 * 4) }
	}
}
