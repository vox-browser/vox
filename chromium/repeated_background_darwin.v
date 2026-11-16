module main

import platform

@[export: 'vox_document_repeated_background_pixels']
fn document_repeated_background_pixels(pixels &u8, width i32, height i32, pitch i32,
	first_x i32, first_y i32, source &u8, sw i32, sh i32, x f32, y f32,
	clip &f32, color &u8, border &C.VoxGraphiteShape) i32 {
	if pixels == unsafe { nil } || source == unsafe { nil } || clip == unsafe { nil }
		|| color == unsafe { nil } || border == unsafe { nil } || width <= 0 || height <= 0
		|| width > 4096 || height > 4096 || int(width) * int(height) > 4 * 1024 * 1024
		|| pitch < width * 4 || pitch > 4096 * 4 || sw <= 0 || sh <= 0
		|| sw > 4096 || sh > 4096 || int(sw) * int(sh) > 4 * 1024 * 1024 {
		return 0
	}
	work := platform.begin_thread_scratch('repeated background raster callback')
	defer { work.finish() }
	mut bounds := [12]f32{}
	mut rgba := [4]u8{}
	for i in 0 .. 12 { bounds[i] = unsafe { clip[i] } }
	for i in 0 .. 4 { rgba[i] = unsafe { color[i] } }
	swap_document_raster_channels(pixels, width, height, pitch)
	defer { swap_document_raster_channels(pixels, width, height, pitch) }
	return draw_document_sampled_image_tiles_with_decoration(pixels, width, height, pitch, 1,
		int(first_x), int(first_y), unsafe { source.vbytes(int(sw) * int(sh) * 4) }, int(sw), int(sh),
		x, y, f32(sw), f32(sh), int(sw), int(sh), bounds, .repeated_background, false,
		DocumentBitmapDecoration{rgba, *border})
}
