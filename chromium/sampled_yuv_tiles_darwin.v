module main

fn draw_document_sampled_yuv_tiles(pixels &u8, width i32, height i32, pitch i32,
	backdrop i32, first_x int, first_y int, source []u8, sw int, sh int,
	x f32, y f32, dw f32, dh f32, nw int, nh int, clip [12]f32, gpu_mips bool, atlas bool, jpeg_full bool) i32 {
	kind := if jpeg_full {
		DocumentSampledTileKind.jpeg
	} else if atlas {
		DocumentSampledTileKind.yuv_atlas
	} else {
		DocumentSampledTileKind.yuv
	}
	return draw_document_sampled_image_tiles(pixels, width, height, pitch, backdrop, first_x, first_y,
		source, sw, sh, x, y, dw, dh, nw, nh, clip, kind, gpu_mips)
}
