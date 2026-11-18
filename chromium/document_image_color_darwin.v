module main

import gg.canvas

// Synchronous PNG bridge calls borrow the document working space. Image
// filtering and conversion finish before the caller restores this scope.
__global document_png_p3_scope = false

fn document_png_supports_p3_raster() bool {
	return C.native_document_raster_uses_p3() != 0 && canvas.document_image_srgb_gamut_supported()
}

fn select_document_png_color_space() bool {
	previous := document_png_p3_scope
	document_png_p3_scope = document_png_supports_p3_raster()
	return previous
}

@[export: 'vox_document_png_space_is_p3']
fn document_png_space_is_p3() i32 {
	return i32(document_png_p3_scope)
}
