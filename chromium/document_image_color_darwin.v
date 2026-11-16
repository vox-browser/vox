module main

import os
import gg.canvas

const document_image_p3_diagnostic = os.getenv('VOX_DIAGNOSTIC_DOCUMENT_IMAGE_P3') == '1'

// Synchronous PNG bridge calls borrow the document working space. Image
// filtering and conversion finish before the caller restores this scope.
__global document_png_p3_scope = false

fn select_document_png_color_space() bool {
	previous := document_png_p3_scope
	$if vox_diagnostic_document_image_p3 ? {
		document_png_p3_scope = document_image_p3_diagnostic
			&& canvas.document_image_srgb_gamut_supported()
			&& C.native_document_raster_uses_p3() != 0
	} $else {
		document_png_p3_scope = false
	}
	return previous
}

@[export: 'vox_document_png_space_is_p3']
fn document_png_space_is_p3() i32 {
	return i32(document_png_p3_scope)
}
