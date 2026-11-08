module cpuraster

import crypto.sha256
import os

fn test_retained_text_shadow_matches_native_smoothing_and_single_tint() {
	$if macos {
		font := os.join_path(@VMODROOT, 'pixel_tests/sites/tarsnap/www.tarsnap.com/font/NotoSans-Regular-subset.ttf')
		// Original vox_skia_shadow() readback, including baseline snapping,
		// default/alias/AA/subpixel smoothing and a single 50% blue tint.
		hashes := ['0f04508fc155d39bd5870c7408515111c1f7f8eaf54d8d39393e7e607d69d099',
			'3f394818a9dafe9f9779de77e6c6b0d077fc3486b4c00c390f3e108a9ea0cbe0',
			'918807c98720ec9d38dfdd7fb6e95ad49002ae620cf116ed99ec32db727468db',
			'0f04508fc155d39bd5870c7408515111c1f7f8eaf54d8d39393e7e607d69d099']
		for smoothing in 0 .. 4 {
			run := CanvasGlyphRun{font_path: font, font_size: 24, glyphs: [u16(5)],
				positions: [f32(0), 0], translation: [f32(8), 30]!, smoothing: smoothing}
			pixels := rasterize_text_shadow(48, 48, run, [f32(1), 0, 0, 1, 0, 0]!,
				0x800000ff, 4, []) or { panic('text shadow') }
			assert sha256.sum(pixels).hex() == hashes[smoothing]
			for i := 0; i < pixels.len; i += 4 {
				assert pixels[i+3] <= 128
				if pixels[i+3] != 0 { assert pixels[i..i+3] == [u8(0), 0, 255] }
			}
		}
	}
}

fn test_text_shadow_rejects_invalid_surfaces() {
	if _ := rasterize_text_shadow(0, 20, CanvasGlyphRun{}, [f32(1), 0, 0, 1, 0, 0]!, 0xff000000, 4, []) { assert false }
}
