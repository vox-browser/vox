module cpuraster

import os
import runtime

fn test_prepared_glyph_masks_match_serial_at_subpixel_origins() {
	$if !cpuraster_freetype ? {
		if runtime.nr_cpus() < 2 { return }
		previous := os.getenv_opt('VOX_SERIAL_CPU_RASTER')
		defer {
			if value := previous {
				os.setenv('VOX_SERIAL_CPU_RASTER', value, true)
			} else {
				os.unsetenv('VOX_SERIAL_CPU_RASTER')
			}
		}
		os.unsetenv('VOX_SERIAL_CPU_RASTER')
		run := CanvasGlyphRun{
			font_path:         '/System/Library/Fonts/Supplemental/Verdana Bold.ttf'
			font_size:         26.66
			glyphs:            [u16(43), 68, 70, 78, 72, 85, 3, 49, 72, 90, 86, 43]
			positions:         [f32(221.20312), 50, 243.52826, 50, 261.3363, 50, 277.02246, 50,
				294.90863, 50, 312.61252, 50, 325.8644, 50, 334.9767, 50, 357.5492, 50, 375.2531,
				50, 401.36633, 50, 221.20312, 50]
			retained:          true
			chromium_coverage: true
			baseline_snap:     true
		}
		device := SkAffine{ sx: 1, sy: 1, tx: -202, ty: -18 }
		mut strike := glyph_strike_template(run.font_size, device, 0) or { panic('invalid strike') }
		defer { strike.release() }
		strike.snap_y = true
		strike.table = identity_mask_gamma_table
		mut lazy := LazyGlyphFace{ path: run.font_path }
		defer { lazy.release() }
		mut entry := CachedGlyphStrike{}
		rounding := SkAffine{ ...device, tx: device.tx + glyph_subpixel_round, ty: device.ty + 0.5 }
		entry.prepare_glyph_masks(mut strike, mut lazy, run, []GlyphRoute{len: run.glyphs.len},
			0, rounding)
		assert entry.glyphs.len >= glyph_batch_min
		mut bytes := 0
		for key, parallel in entry.glyphs {
			serial := strike.make_glyph(u16(key >> 4), int((key >> 2) & 3), int(key & 3))
			assert parallel == serial
			bytes += parallel.image.len
		}
		assert bytes == entry.bytes
		// The full draw still composites repeated and overlapping glyphs in order.
		mut serial := []u8{len: 256 * 48 * 4, init: 255}
		mut parallel := serial.clone()
		transform := [f32(1), 0, 0, 1, -202, -18]!
		os.setenv('VOX_SERIAL_CPU_RASTER', '1', true)
		assert fill_canvas_glyphs(mut serial, 256, 48, 1024, 2, run, transform, 0xff123456, none,
			1, .src_over, [], none)
		os.unsetenv('VOX_SERIAL_CPU_RASTER')
		assert fill_canvas_glyphs(mut parallel, 256, 48, 1024, 2, run, transform, 0xff123456, none,
			1, .src_over, [], none)
		assert serial == parallel
	}
}
