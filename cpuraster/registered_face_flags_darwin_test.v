// vtest build: macos
module cpuraster

import os
import time

fn test_registered_coretext_faces_reuse_flags_and_preserve_glyph_pixels() {
	$if macos {
		directory := os.join_path(os.temp_dir(), 'vox-face-flags-${os.getpid()}-${time.sys_mono_now()}')
		os.mkdir_all(directory) or { panic(err) }
		defer { os.rmdir_all(directory) or {} }
		binary := os.join_path(directory, 'face-flags')
		fixture := os.join_path(@VMODROOT, 'cpuraster/fixtures/registered_face_flags.c')
		font := os.join_path(@VMODROOT, 'Tests/Browser/Brave/resources/Ahem.ttf')
		compiled := os.exec(['clang', '-std=c11', '-framework', 'CoreText', '-framework',
			'CoreGraphics', '-framework', 'CoreFoundation', fixture, '-o', binary])
		assert compiled.exit_code == 0, compiled.output
		result := os.exec([binary, font])
		assert result.exit_code == 0, result.output
	}
}
