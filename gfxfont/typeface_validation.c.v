module gfxfont

$if darwin {
	#flag -framework CoreFoundation
	#flag -framework CoreText
} $else {
	#pkgconfig freetype2
	#flag -lpthread
}

#include "@DIR/typeface_validation.h"

fn C.vox_typeface_data_is_valid(data &u8, size uint, index i32) i32

// Gfx::Typeface::try_load_from_temporary_memory(): whether the platform font
// manager behind LibWeb's Skia accepts this font data.
pub fn typeface_data_is_valid(data []u8, index int) bool {
	return C.vox_typeface_data_is_valid(data.data, uint(data.len), i32(index)) != 0
}
