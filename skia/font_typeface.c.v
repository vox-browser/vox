// Gfx::Typeface::try_load_from_temporary_memory's native Skia decoder.
module skia

$if linux {
	#flag @DIR/../Build/linux/native/skia.a
} $else {
	#flag @DIR/font_typeface.o
}
#include "font_typeface.h"

fn C.vox_skia_font_typeface_is_valid(data &u8, size uint, index int) int

pub fn font_typeface_is_valid(data []u8, index int) bool {
	return C.vox_skia_font_typeface_is_valid(data.data, uint(data.len), index) != 0
}
