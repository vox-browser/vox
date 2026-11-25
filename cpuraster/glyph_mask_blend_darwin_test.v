module cpuraster

import runtime

fn test_weighted_glyph_stripes_split_concentrated_mask_pixels() {
	for columns in [true, false] {
		bounds := if columns { IRect{7, 7, 263, 27} } else { IRect{7, 7, 27, 263} }
		dense := if columns { IRect{7, 7, 47, 27} } else { IRect{7, 7, 27, 47} }
		outlier := if columns { IRect{259, 7, 263, 27} } else { IRect{7, 259, 27, 263} }
		mut blits := []GlyphMaskBlit{len: 8, init: GlyphMaskBlit{Mask{}, dense}}
		blits << GlyphMaskBlit{Mask{}, outlier}
		assert glyph_blend_stripe_edges(blits, bounds, 4, false) == [7, 71, 135, 199, 263]!
		assert glyph_blend_stripe_edges(blits, bounds, 4, true) == [7, 17, 27, 37, 263]!
	}
}

fn test_two_glyph_stripes_run_on_caller_and_worker() {
	$if !cpuraster_freetype ? {
		if runtime.nr_cpus() < 2 || glyph_blend_dispatch_apply || C.vox_scan_workers_disabled() { return }
		width, height := 241, 20
		mut pixels := []u8{len: width * height * 4}
		blitter := new_pipeline_blitter(mut pixels, width * 4, 0xff123456, 1, .src_over)
		bounds := IRect{0, 0, width, height}
		mask := Mask{
			bounds:    bounds
			row_bytes: width
			image:     []u8{len: width * height, init: 255}
		}
		mut work := GlyphMaskBlend{
			blitter:        &blitter
			blits:          [GlyphMaskBlit{mask, bounds}]
			bounds:         bounds
			lanes:          2
			record_threads: true
		}
		mut caller := u64(0)
		assert C.pthread_threadid_np(unsafe { nil }, &caller) == 0
		assert work.draw()
		assert work.threads[1] == caller
		assert work.threads[0] != 0 && work.threads[0] != caller
		for i in 0 .. width * height {
			assert pixels[i * 4..i * 4 + 4] == [u8(0x12), 0x34, 0x56, 0xff]
		}
	}
}

fn test_short_retained_run_blends_large_overlapping_masks_in_paint_order() {
	width, height := 256, 76
	pitch := width * 4 + 12
	initial := []u8{len: pitch * height, init: if index % 4 == 3 {
		u8(255)
	} else {
		u8(index * 37)
	}}
	run := CanvasGlyphRun{
		font_path:         '/System/Library/Fonts/Supplemental/Verdana Bold.ttf'
		font_size:         64
		glyphs:            [u16(43), 68, 70, 78, 72, 85, 49, 58]
		positions:         [f32(-10.25), 50, 22.5, 50, 52.25, 50, 80.75, 50, 113, 50, 140.25, 50,
			172.5, 50, 203.75, 50]
		retained:          true
		chromium_coverage: true
		baseline_snap:     true
		paint_color:       [f32(0.3), 0.7, 0.4, 0.6]!
	}
	transform := [f32(1), 0, 0, 1, 0, 0]!
	mut serial := initial.clone()
	mut parallel := initial.clone()
	for index in 0 .. run.glyphs.len {
		single := CanvasGlyphRun{
			...run
			glyphs:    run.glyphs[index..index + 1]
			positions: run.positions[2 * index..2 * index + 2]
		}
		assert fill_canvas_glyphs(mut serial, width, height, pitch, 2, single, transform,
			0x994db366, none, 1, .src_over, [], none)
	}
	assert fill_canvas_glyphs(mut parallel, width, height, pitch, 2, run, transform,
		0x994db366, none, 1, .src_over, [], none)
	assert serial == parallel
	assert parallel != initial
}

fn test_glyph_mask_stripes_match_ordered_blends_in_both_directions() {
	if runtime.nr_cpus() < 2 || C.vox_scan_workers_disabled() { return }
	for size in [[211, 63]!, [63, 211]!] {
		width, height := size[0], size[1]
		pitch := width * 4 + 12
		initial := []u8{len: pitch * height, init: if index % 4 == 3 {
			u8(255)
		} else {
			u8(index * 37)
		}}
		viewport := IRect{0, 0, width, height}
		mut batch := GlyphMaskBatch{}
		for mask_index in 0 .. 4 {
			bounds := IRect{mask_index * 3 - 7, mask_index * 4 - 9, width - 3 + mask_index, height + 4 - mask_index}
			row_bytes := bounds.width() + 7
			mask := Mask{
				bounds:    bounds
				row_bytes: row_bytes
				image:     []u8{len: row_bytes * bounds.height(), init: u8(mask_index * 29 + index * 37)}
			}
			batch.add(mask, bounds.intersect(viewport) or { panic('expected a visible mask') })
		}
		for lowp in [true, false] {
			mut serial := initial.clone()
			mut parallel := initial.clone()
			serial_pipeline := new_pipeline_blitter(mut serial, pitch, 0xff1a92c5, 0.63, .src_over)
			parallel_pipeline := new_pipeline_blitter(mut parallel, pitch, 0xff1a92c5, 0.63, .src_over)
			mut serial_blitter := PipelineBlitter{ ...serial_pipeline, lowp: lowp }
			parallel_blitter := PipelineBlitter{ ...parallel_pipeline, lowp: lowp }
			for blit in batch.blits { serial_blitter.blit_mask(&blit.mask, blit.clip) }
			assert batch.blend_parallel(&parallel_blitter)
			assert serial == parallel
			assert parallel != initial
		}
	}
}
