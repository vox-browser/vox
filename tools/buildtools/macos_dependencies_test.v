module buildtools

import os

fn test_harfbuzz_features_only_enable_coretext() {
	assert hb_features('#mesondefine HB_HAS_CORETEXT\n#mesondefine HB_HAS_GRAPHITE\n#mesondefine HB_HAS_ICU') == '#define HB_HAS_CORETEXT 1\n/* #undef HB_HAS_GRAPHITE */\n/* #undef HB_HAS_ICU */\n'
}

fn test_macos_dependencies_require_headers_and_matching_libraries() ! {
	root := temporary(os.temp_dir(), 'vox-macos-deps-')!
	defer { remove(root) or {} }
	mkdir(join(root, 'include/avif'))!
	mkdir(join(root, 'lib'))!
	os.write_file(join(root, 'include/avif/avif.h'), '')!
	assert !macos_dependency_present(root, 'libavif')
	os.write_file(join(root, 'lib/libavif.dylib'), '')!
	assert macos_dependency_present(root, 'libavif')
	for library, header in {
		'avformat': 'avformat.h'
		'avcodec':  'avcodec.h'
		'avutil':   'avutil.h'
		'swscale':  'swscale.h'
	} {
		mkdir(join(root, 'include/lib${library}'))!
		os.write_file(join(root, 'include/lib${library}/${header}'), '')!
		os.write_file(join(root, 'lib/lib${library}.dylib'), '')!
	}
	assert macos_dependency_present(root, 'ffmpeg')
	os.rm(join(root, 'lib/libswscale.dylib'))!
	assert !macos_dependency_present(root, 'ffmpeg')
	assert !macos_dependency_present(root, 'unknown')
}
