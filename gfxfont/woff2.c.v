module gfxfont

// GNU ld resolves archive dependencies from left to right with --as-needed.
#flag linux @DIR/../Build/linux/native/gfxfont.a

$if darwin {
	$if arm64 {
		#flag -I @DIR/../../3rd/ladybird/Build/release/vcpkg_installed/arm64-osx-dynamic/include
		#flag -L @DIR/../../3rd/ladybird/Build/release/vcpkg_installed/arm64-osx-dynamic/lib
		#flag -Wl,-rpath,@DIR/../../3rd/ladybird/Build/release/vcpkg_installed/arm64-osx-dynamic/lib
	} $else {
		#flag -I @DIR/../../3rd/ladybird/Build/release/vcpkg_installed/x64-osx-dynamic/include
		#flag -L @DIR/../../3rd/ladybird/Build/release/vcpkg_installed/x64-osx-dynamic/lib
		#flag -Wl,-rpath,@DIR/../../3rd/ladybird/Build/release/vcpkg_installed/x64-osx-dynamic/lib
	}
	#flag -lc++
} $else {
	#flag -lstdc++
}
#flag -lwoff2dec
#flag -lwoff2common
#flag -lbrotlidec
#flag -lbrotlicommon
$if !linux {
	#flag @DIR/woff2.o
}
#include "woff2.h"

fn C.vox_woff2_convert_to_ttf(data &u8, size uint, output_size &uint) &u8
fn C.vox_woff2_free(data voidptr)

pub fn convert_woff2_to_sfnt(data []u8) ![]u8 {
	mut size := uint(0)
	output := C.vox_woff2_convert_to_ttf(data.data, uint(data.len), &size)
	if output == unsafe { nil } { return error('Failed to convert the WOFF2 font to TTF') }
	defer { C.vox_woff2_free(output) }
	return unsafe { output.vbytes(int(size)).clone() }
}
