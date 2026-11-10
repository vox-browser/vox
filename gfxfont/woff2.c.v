module gfxfont

// GNU ld resolves archive dependencies from left to right with --as-needed.
#flag linux @DIR/../Build/linux/native/gfxfont.a
#flag windows -Wl,@DIR/../Build/deps/windows/native/gfxfont.a,-lstdc++

$if darwin {
	$if arm64 {
		#flag -I @DIR/../../3rd/ladybird/Build/release/vcpkg_installed/arm64-osx-dynamic/include
		$if !vox_filter_worker_minimal_links ? {
			#flag -L @DIR/../../3rd/ladybird/Build/release/vcpkg_installed/arm64-osx-dynamic/lib
			#flag -Wl,-rpath,@DIR/../../3rd/ladybird/Build/release/vcpkg_installed/arm64-osx-dynamic/lib
		}
	} $else {
		#flag -I @DIR/../../3rd/ladybird/Build/release/vcpkg_installed/x64-osx-dynamic/include
		$if !vox_filter_worker_minimal_links ? {
			#flag -L @DIR/../../3rd/ladybird/Build/release/vcpkg_installed/x64-osx-dynamic/lib
			#flag -Wl,-rpath,@DIR/../../3rd/ladybird/Build/release/vcpkg_installed/x64-osx-dynamic/lib
		}
	}
	#flag -lc++
} $else {
	#flag -lstdc++
}
$if !vox_filter_worker_minimal_links ? {
	#flag -lwoff2dec
	#flag -lwoff2common
	#flag -lbrotlidec
	#flag -lbrotlicommon
}
$if macos {
	#flag @DIR/woff2.o
}
#include "woff2.h"

fn C.vox_woff2_convert_to_ttf(data &u8, size uint, output_size &uint) &u8
fn C.vox_woff2_free(data voidptr)

pub fn convert_woff2_to_sfnt(data []u8) ![]u8 {
	if woff2_decompressed_table_data_size(data)! > woff2_max_output_size {
		return error('Decompressed WOFF2 table data is too big')
	}
	mut size := uint(0)
	output := C.vox_woff2_convert_to_ttf(data.data, uint(data.len), &size)
	if output == unsafe { nil } { return error('Failed to convert the WOFF2 font to TTF') }
	defer { C.vox_woff2_free(output) }
	return unsafe { output.vbytes(int(size)).clone() }
}
