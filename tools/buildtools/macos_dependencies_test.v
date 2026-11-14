module buildtools

import os

fn test_harfbuzz_binary_releases_are_pinned_for_both_macos_architectures() {
	assert hb_binary_sha('arm64')!.len == 64
	assert hb_binary_sha('amd64')!.len == 64
	assert hb_binary_sha('arm64')! != hb_binary_sha('amd64')!
	if _ := hb_binary_sha('unknown') {
		assert false, 'unsupported architecture accepted'
	}
}

fn test_harfbuzz_package_rejects_missing_and_corrupt_native_archives() ! {
	root := temporary(os.temp_dir(), 'vox-harfbuzz-package-')!
	defer { remove(root) or {} }
	mkdir(join(root, 'include/harfbuzz'))!
	mkdir(join(root, '.vpm-binaries'))!
	os.write_file(join(root, 'include/harfbuzz/hb.h'), '')!
	os.write_file(join(root, 'LICENSE.harfbuzz'), '')!
	assert !hb_artifact_matches(root, 'a'.repeat(64))
	library := join(root, '.vpm-binaries/libharfbuzz.a')
	os.write_file(library, 'verified library')!
	sha := digest(library)!
	assert hb_artifact_matches(root, sha)
	os.write_file(library, 'corrupt')!
	assert !hb_artifact_matches(root, sha)
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
