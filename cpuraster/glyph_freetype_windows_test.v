module cpuraster

import os
import time

fn test_windows_freetype_masks_from_a_unicode_path() {
	source := os.join_path(@VMODROOT, 'pixel_tests/sites/tarsnap/www.tarsnap.com/font/NotoSans-Regular-subset.ttf')
	path := os.join_path(os.temp_dir(), 'vox-freetype-🔔-${os.getpid()}-${time.sys_mono_now()}.ttf')
	os.cp(source, path) or { panic(err) }
	defer { os.rm(path) or {} }
	run := CanvasGlyphRun{
		font_path:   path
		font_size:   24
		glyphs:      [u16(5)]
		positions:   [f32(0), 0]
		translation: [f32(6), 30]!
		retained:    true
	}
	mut pixels := []u8{len: 40 * 40 * 4}
	assert fill_canvas_glyphs(mut pixels, 40, 40, 160, 2, run, [f32(1), 0, 0, 1, 0, 0]!,
		0xff000000, none, 1, .src_over, [], none)
	mut opaque := 0
	mut partial := 0
	for index in 0 .. 40 * 40 {
		alpha := pixels[index * 4 + 3]
		opaque += int(alpha == 255)
		partial += int(alpha > 0 && alpha < 255)
	}
	assert opaque > 0
	assert partial > 0
	assert pixels[3] == 0
	os.rm(path) or { panic(err) }
}
