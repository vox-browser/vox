// LibUnicode/CaseMapping.cpp: ICU case conversion and fine length-changing edits.
module platform

$if linux {
	#flag @DIR/../Build/linux/native/platform.a
} $else {
	#flag @DIR/unicode_case_mapping.o
}
// Use the ICU that LibJS's property bridge and the vcpkg FFmpeg/Skia tree
// already load. Homebrew's ICU headers would select a second major version's
// versioned API for every Unicode caller, mapping another libicuuc/libicudata
// pair into every launch.
$if arm64 {
	#flag darwin -I@DIR/../../3rd/ladybird/Build/release/vcpkg_installed/arm64-osx-dynamic/include
	$if !vox_filter_worker_minimal_links ? {
		#flag darwin @DIR/../../3rd/ladybird/Build/release/vcpkg_installed/arm64-osx-dynamic/lib/libicuuc.dylib
		#flag darwin -Wl,-rpath,@DIR/../../3rd/ladybird/Build/release/vcpkg_installed/arm64-osx-dynamic/lib
	}
} $else {
	#flag darwin -I@DIR/../../3rd/ladybird/Build/release/vcpkg_installed/x64-osx-dynamic/include
	$if !vox_filter_worker_minimal_links ? {
		#flag darwin @DIR/../../3rd/ladybird/Build/release/vcpkg_installed/x64-osx-dynamic/lib/libicuuc.dylib
		#flag darwin -Wl,-rpath,@DIR/../../3rd/ladybird/Build/release/vcpkg_installed/x64-osx-dynamic/lib
	}
}
#flag darwin -lc++
#flag linux -lstdc++
$if linux {
	#pkgconfig icu-uc icu-i18n
}
#include "unicode_case_mapping.h"

struct C.LibWebVCaseEdit {
	source_start    int
	source_length   int
	rendered_start  int
	rendered_length int
}

struct C.LibWebVCaseMapping {
	text        &u16
	text_length int
	edits       &C.LibWebVCaseEdit
	edit_count  int
}

fn C.libweb_v_case_mapping(input &u16, length int, locale &char, transform int, output &C.LibWebVCaseMapping) bool
fn C.libweb_v_case_mapping_free(output &C.LibWebVCaseMapping)

pub struct TextMappingEdit {
pub mut:
	source_start    int
	source_length   int
	rendered_start  int
	rendered_length int
}

pub struct CaseMappedText {
pub:
	units []u16
	edits []TextMappingEdit
}

pub fn transform_text_case_with_edits(units []u16, locale string, transform TextCaseTransform) CaseMappedText {
	mut output := C.LibWebVCaseMapping{}
	// Enum mapping mirrors Unicode::CaseMapping rather than TextCaseTransform.
	mapping := match transform {
		.lowercase { 0 }
		.uppercase { 1 }
		.titlecase { 2 }
	}

	success := C.libweb_v_case_mapping(units.data, units.len, locale.str, mapping, &output)
	assert success
	defer { C.libweb_v_case_mapping_free(&output) }
	mut result_units := []u16{len: output.text_length}
	for index in 0 .. output.text_length {
		result_units[index] = unsafe { output.text[index] }
	}
	mut edits := []TextMappingEdit{cap: output.edit_count}
	for index in 0 .. output.edit_count {
		edit := unsafe { output.edits[index] }
		edits << TextMappingEdit{edit.source_start, edit.source_length, edit.rendered_start, edit.rendered_length}
	}
	return CaseMappedText{result_units, edits}
}
