// vtest build: macos
module cpuraster

import os
import time

// Registering several keys for one font file parses its descriptors once.
fn test_registered_faces_share_parsed_font_file_descriptors() {
	$if macos {
		directory := os.join_path(os.temp_dir(), 'vox-file-descriptors-${os.getpid()}-${time.sys_mono_now()}')
		os.mkdir_all(directory) or { panic(err) }
		defer { os.rmdir_all(directory) or {} }
		binary := os.join_path(directory, 'file-descriptors')
		fixture := os.join_path(@VMODROOT, 'cpuraster/fixtures/font_file_descriptors.c')
		font := os.join_path(@VMODROOT, 'Tests/Browser/Brave/resources/Ahem.ttf')
		compiled := os.exec(['clang', '-std=c11', '-framework', 'CoreText', '-framework',
			'CoreGraphics', '-framework', 'CoreFoundation', fixture, '-o', binary])
		assert compiled.exit_code == 0, compiled.output
		cached := os.exec([binary, font])
		assert cached.exit_code == 0, cached.output
		assert cached.output.contains('1 descriptor parses'), cached.output
		uncached := os.exec(['env', 'VOX_DISABLE_FONT_FILE_DESCRIPTOR_CACHE=1', binary, font])
		assert uncached.exit_code == 0, uncached.output
		assert uncached.output.contains('3 descriptor parses'), uncached.output
	}
}
